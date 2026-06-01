// lib/data/repositories/documents_repository.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../../features/documents/services/sale_agreement_pdf.dart';

class SignerInfo {
  final String id;
  final String signerRole;       // client | vendor_witness | buyer_witness
  final int signerOrder;
  final String? fullName;
  final String? email;
  final String status;           // pending | awaiting_signer | otp_verified | signed
  final DateTime? notifiedAt;
  final DateTime? openedAt;
  final DateTime? signedAt;
  final String? signatureMethod;
  final String? signingToken;
  final DateTime? tokenExpiresAt;

  SignerInfo({
    required this.id,
    required this.signerRole,
    required this.signerOrder,
    this.fullName,
    this.email,
    required this.status,
    this.notifiedAt,
    this.openedAt,
    this.signedAt,
    this.signatureMethod,
    this.signingToken,
    this.tokenExpiresAt,
  });

  factory SignerInfo.fromMap(Map<String, dynamic> m) => SignerInfo(
    id: m['id'] as String,
    signerRole: m['signer_role'] as String,
    signerOrder: m['signer_order'] as int,
    fullName: m['full_name'] as String?,
    email: m['email'] as String?,
    status: m['status'] as String,
    notifiedAt: m['notified_at'] != null
        ? DateTime.parse(m['notified_at'] as String)
        : null,
    openedAt: m['opened_at'] != null
        ? DateTime.parse(m['opened_at'] as String)
        : null,
    signedAt: m['signed_at'] != null
        ? DateTime.parse(m['signed_at'] as String)
        : null,
    signatureMethod: m['signature_method'] as String?,
    signingToken: m['signing_token'] as String?,
    tokenExpiresAt: m['token_expires_at'] != null
        ? DateTime.parse(m['token_expires_at'] as String)
        : null,
  );

  String get roleLabel => switch (signerRole) {
    'client' => 'Purchaser',
    'vendor_witness' => "Vendor's witness",
    'buyer_witness' => "Buyer's witness",
    _ => signerRole,
  };

  bool get isSigned => status == 'signed';
  bool get isCurrentlyWaiting =>
      status == 'awaiting_signer' || status == 'otp_verified';
  bool get isMissingDetails =>
      (fullName == null || fullName!.isEmpty) ||
          (email == null || email!.isEmpty);
}

class SignatureProgress {
  final String documentId;
  final String docStatus;
  final DateTime? agencySignedAt;
  final String? agencySignerName;
  final DateTime? expiresAt;
  final List<SignerInfo> signers;

  SignatureProgress({
    required this.documentId,
    required this.docStatus,
    this.agencySignedAt,
    this.agencySignerName,
    this.expiresAt,
    required this.signers,
  });
}

class SendForSignatureResult {
  final String documentId;
  final String clientSigningToken;
  final String clientEmail;
  SendForSignatureResult({
    required this.documentId,
    required this.clientSigningToken,
    required this.clientEmail,
  });
}

class DocumentsRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Uploads the unsigned PDF to storage. Returns the storage path.
  Future<String> uploadUnsignedPdf({
    required String agencyId,
    required Uint8List pdfBytes,
  }) async {
    final filename =
        'unsigned_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = '$agencyId/$filename';
    await _c.storage.from('unsigned-documents').uploadBinary(
      path,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: false,
      ),
    );
    return path;
  }

  /// Calls the RPC to create the document + signers + tokens.
  Future<SendForSignatureResult> createSignatureRequest({
    required String contractId,
    required String agencySignatureId,
    required String unsignedPdfPath,
    required String vendorWitnessName,
    required String vendorWitnessEmail,
    String? buyerWitnessName,
    String? buyerWitnessEmail,
    int expiresInDays = 14,
  }) async {
    final res = await _c.rpc('create_signature_request', params: {
      'p_contract_id': contractId,
      'p_agency_signature_id': agencySignatureId,
      'p_unsigned_pdf_path': unsignedPdfPath,
      'p_vendor_witness_name': vendorWitnessName,
      'p_vendor_witness_email': vendorWitnessEmail,
      'p_buyer_witness_name': buyerWitnessName,
      'p_buyer_witness_email': buyerWitnessEmail,
      'p_expires_in_days': expiresInDays,
    });

    if (res is List && res.isNotEmpty) {
      final r = res.first as Map<String, dynamic>;
      return SendForSignatureResult(
        documentId: r['document_id'] as String,
        clientSigningToken: r['client_signing_token'] as String,
        clientEmail: r['client_email'] as String,
      );
    }
    throw Exception('Could not send for signature');
  }

  /// Fetches signature progress for a contract — the latest document
  /// and all its signers in order.
  Future<SignatureProgress?> progressForContract(String contractId) async {
    final docRows = await _c
        .from('documents')
        .select(
        'id, status, agency_signed_at, agency_signature_id, expires_at')
        .eq('contract_id', contractId)
        .order('created_at', ascending: false)
        .limit(1);

    if (docRows.isEmpty) return null;
    final doc = docRows.first;

    String? agencySignerName;
    if (doc['agency_signature_id'] != null) {
      final sig = await _c
          .from('agency_signatures')
          .select('signer_name')
          .eq('id', doc['agency_signature_id'])
          .maybeSingle();
      agencySignerName = sig?['signer_name'] as String?;
    }

    final signerRows = await _c
        .from('document_signers')
        .select()
        .eq('document_id', doc['id'])
        .order('signer_order');

    final signers = signerRows
        .map<SignerInfo>((s) => SignerInfo.fromMap(s as Map<String, dynamic>))
        .toList();

    return SignatureProgress(
      documentId: doc['id'] as String,
      docStatus: doc['status'] as String,
      agencySignedAt: doc['agency_signed_at'] != null
          ? DateTime.parse(doc['agency_signed_at'] as String)
          : null,
      agencySignerName: agencySignerName,
      expiresAt: doc['expires_at'] != null
          ? DateTime.parse(doc['expires_at'] as String)
          : null,
      signers: signers,
    );
  }

  /// Generates the final signed PDF (with all signatures embedded
  /// and an audit page) for a fully-signed document. Returns the
  /// storage path of the new signed PDF.
  Future<String> finalizeSignedDocument({
    required String documentId,
    required String agencyId,
  }) async {
    final doc = await _c.from('documents').select('''
          id, status, contract_id, agency_signature_id,
          agency_signed_at, current_pdf_path
        ''').eq('id', documentId).single();

    if (doc['status'] != 'fully_signed' && doc['status'] != 'completed') {
      throw Exception(
          'Document is not fully signed yet (status: ${doc['status']})');
    }

    final signers = await _c
        .from('document_signers')
        .select()
        .eq('document_id', documentId)
        .order('signer_order');

    final contract = await _c.from('contracts').select('''
          *,
          client:clients(id, full_name, phone, email, address),
          property:properties(id, title, location, state, lga, size_sqm),
          agency:agencies(id, name, rc_number, address, logo_url)
        ''').eq('id', doc['contract_id']).single();

    final agencySig = await _c
        .from('agency_signatures')
        .select()
        .eq('id', doc['agency_signature_id'])
        .single();

    final agencyBytes = await _c.storage
        .from('agency-signatures')
        .download(agencySig['signature_image_path']);

    Uint8List? clientBytes;
    Uint8List? vendorWitnessBytes;
    Uint8List? buyerWitnessBytes;

    for (final s in signers) {
      final m = s as Map<String, dynamic>;
      if (m['signature_path'] == null) continue;
      final bytes = await _c.storage
          .from('signer-signatures')
          .download(m['signature_path'] as String);

      switch (m['signer_role']) {
        case 'client':
          clientBytes = bytes;
          break;
        case 'vendor_witness':
          vendorWitnessBytes = bytes;
          break;
        case 'buyer_witness':
          buyerWitnessBytes = bytes;
          break;
      }
    }

    final auditEntries = <SignerAuditInfo>[
      SignerAuditInfo(
        role: 'Vendor (Agency)',
        name: agencySig['signer_name'] as String,
        method: 'Saved signature',
        signedAt: DateTime.parse(doc['agency_signed_at'] as String),
      ),
    ];

    for (final s in signers) {
      final m = s as Map<String, dynamic>;
      if (m['signature_path'] == null) continue;
      auditEntries.add(SignerAuditInfo(
        role: _roleLabel(m['signer_role'] as String),
        name: m['full_name'] as String? ?? '',
        email: m['email'] as String?,
        method: m['signature_method'] as String? ?? 'unknown',
        signedAt: DateTime.parse(m['signed_at'] as String),
        ip: m['signer_ip'] as String?,
        otpVerifiedAt: m['opened_at'] != null
            ? DateTime.parse(m['opened_at'] as String)
            : null,
      ));
    }

    final clientRow = signers
        .firstWhere((s) => s['signer_role'] == 'client') as Map<String, dynamic>;
    final vendorWitnessRow = signers
        .firstWhere((s) => s['signer_role'] == 'vendor_witness')
    as Map<String, dynamic>;
    final buyerWitnessRow = signers
        .firstWhere((s) => s['signer_role'] == 'buyer_witness')
    as Map<String, dynamic>;

    final client = contract['client'] as Map<String, dynamic>;
    final property = contract['property'] as Map<String, dynamic>;
    final agency = contract['agency'] as Map<String, dynamic>;

    final input = SaleAgreementInput(
      contractId: doc['contract_id'] as String,
      agencyName: agency['name'] as String,
      agencyRcNumber: agency['rc_number'] as String?,
      agencyAddress: agency['address'] as String? ?? '',
      agencySignatureImage: agencyBytes,
      agencySignerName: agencySig['signer_name'] as String,
      agencySignerTitle: agencySig['signer_title'] as String?,
      clientFullName: client['full_name'] as String,
      clientAddress: client['address'] as String?,
      clientPhone: client['phone'] as String,
      clientEmail: client['email'] as String?,
      propertyTitle: property['title'] as String,
      propertyLocation: property['location'] as String,
      propertyState: property['state'] as String,
      propertyLga: property['lga'] as String? ?? '',
      propertySizeSqm: property['size_sqm'] as num?,
      unitLabel: contract['unit_label'] as String?,
      contractNo: contract['contract_no'] as String,
      totalPriceNgn: contract['total_price_ngn'] as num,
      initialDeposit: contract['initial_deposit_ngn'] as num? ?? 0,
      paymentPlanLabel:
      _planLabelFromDb(contract['payment_plan'] as String),
      planMonths: contract['plan_months'] as int?,
      startDate: DateTime.parse(contract['start_date'] as String),
      agreementDate: DateTime.parse(doc['agency_signed_at'] as String),
      vendorWitnessName: vendorWitnessRow['full_name'] as String? ?? '',
      vendorWitnessOccupation: vendorWitnessRow['occupation'] as String?,
      vendorWitnessAddress: vendorWitnessRow['address'] as String?,
      vendorWitnessSignatureImage: vendorWitnessBytes,
      vendorWitnessSignedAtDisplay: vendorWitnessRow['signed_at'] != null
          ? _formatDate(
          DateTime.parse(vendorWitnessRow['signed_at'] as String))
          : null,
      buyerWitnessName: buyerWitnessRow['full_name'] as String?,
      buyerWitnessOccupation: buyerWitnessRow['occupation'] as String?,
      buyerWitnessAddress: buyerWitnessRow['address'] as String?,
      buyerWitnessSignatureImage: buyerWitnessBytes,
      buyerWitnessSignedAtDisplay: buyerWitnessRow['signed_at'] != null
          ? _formatDate(
          DateTime.parse(buyerWitnessRow['signed_at'] as String))
          : null,
      clientSignatureImage: clientBytes,
      clientSignedAtDisplay: clientRow['signed_at'] != null
          ? _formatDate(DateTime.parse(clientRow['signed_at'] as String))
          : null,
    );

    final pdfBytes = await SaleAgreementPdf.buildSignedWithAudit(
      input: input,
      auditEntries: auditEntries,
    );

    final filename = 'signed_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = '$agencyId/$filename';
    await _c.storage.from('signed-documents').uploadBinary(
      path,
      pdfBytes,
      fileOptions: const FileOptions(
        contentType: 'application/pdf',
        upsert: true,
      ),
    );

    await _c.from('documents').update({
      'signed_pdf_path': path,
      'status': 'completed',
    }).eq('id', documentId);

    return path;
  }

  /// Generates a temporary signed URL to download a signed PDF.
  Future<String> signedPdfUrl(String storagePath) async {
    return await _c.storage
        .from('signed-documents')
        .createSignedUrl(storagePath, 3600);
  }

  /// After createSignatureRequest, sends each signer their branded
  /// signing email. Returns a list of (email, role, success) tuples so
  /// the caller can show which sends worked.
  Future<List<({String email, String role, bool success})>> sendSigningEmails({
    required String contractId,
    required String agencyName,
    required String propertyLabel,
    required String contractNo,
    required String appOrigin,
  }) async {
    final progress = await progressForContract(contractId);
    if (progress == null) return [];

    final results = <({String email, String role, bool success})>[];

    for (final signer in progress.signers) {
      if (signer.email == null || signer.email!.isEmpty) continue;
      if (signer.signingToken == null) continue;

      final signingUrl = '$appOrigin/#/sign/${signer.signingToken}';

      try {
        await _c.functions.invoke(
          'send-signing-request',
          body: {
            'to_email': signer.email,
            'to_name': signer.fullName ?? signer.email,
            'signing_url': signingUrl,
            'signer_role': signer.signerRole,
            'agency_name': agencyName,
            'property_label': propertyLabel,
            'contract_no': contractNo,
            'expires_at': progress.expiresAt?.toIso8601String(),
          },
        );
        results.add((email: signer.email!, role: signer.signerRole, success: true));
      } catch (_) {
        results.add((email: signer.email!, role: signer.signerRole, success: false));
      }
    }

    return results;
  }

  String _roleLabel(String role) => switch (role) {
    'client' => 'Purchaser',
    'vendor_witness' => "Vendor's witness",
    'buyer_witness' => "Buyer's witness",
    _ => role,
  };

  String _planLabelFromDb(String plan) => switch (plan) {
    'outright' => 'Outright',
    'monthly' => 'Monthly',
    'quarterly' => 'Quarterly',
    'biannual' => 'Biannual',
    'annual' => 'Annual',
    'custom' => 'Custom',
    _ => plan,
  };

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

final documentsRepoProvider = Provider((_) => DocumentsRepository());

final contractSignatureProgressProvider =
FutureProvider.family<SignatureProgress?, String>(
      (ref, contractId) async {
    return ref.read(documentsRepoProvider).progressForContract(contractId);
  },
);