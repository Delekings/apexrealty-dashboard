// lib/data/repositories/documents_repository.dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import 'dart:typed_data';
import '../../features/documents/services/sale_agreement_pdf.dart';

class SignatureProgress {
  final String documentId;
  final String docStatus;
  final List<SignerInfo> signers;
  SignatureProgress(
      {required this.documentId,
        required this.docStatus,
        required this.signers});

  factory SignatureProgress.fromMap(Map<String, dynamic> m) {
    return SignatureProgress(
      documentId: m['document_id'] as String,
      docStatus: m['doc_status'] as String,
      signers: (m['signers'] as List)
          .map((s) => SignerInfo.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SignerInfo {
  final String role;
  final int order;
  final String? fullName;
  final String? email;
  final String status;
  final DateTime? signedAt;
  final DateTime? notifiedAt;
  SignerInfo({
    required this.role,
    required this.order,
    this.fullName,
    this.email,
    required this.status,
    this.signedAt,
    this.notifiedAt,
  });

  factory SignerInfo.fromMap(Map<String, dynamic> m) => SignerInfo(
    role: m['role'] as String,
    order: m['order'] as int,
    fullName: m['full_name'] as String?,
    email: m['email'] as String?,
    status: m['status'] as String,
    signedAt: m['signed_at'] != null
        ? DateTime.parse(m['signed_at'] as String)
        : null,
    notifiedAt: m['notified_at'] != null
        ? DateTime.parse(m['notified_at'] as String)
        : null,
  );

  String get roleLabel => switch (role) {
    'client' => 'Client',
    'vendor_witness' => "Vendor's witness",
    'buyer_witness' => "Buyer's witness",
    _ => role,
  };
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
  /// Generates the final signed PDF (with all signatures embedded
  /// and an audit page) for a fully-signed document. Returns the
  /// storage path of the new signed PDF.
  Future<String> finalizeSignedDocument({
    required String documentId,
    required String agencyId,
  }) async {
    // 1. Fetch the document + all its signers in their signed state
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

    // 2. Fetch contract + client + property + agency for the input class
    final contract = await _c.from('contracts').select('''
        *,
        client:clients(id, full_name, phone, email, address),
        property:properties(id, title, location, state, lga, size_sqm),
        agency:agencies(id, name, rc_number, address, logo_url)
      ''').eq('id', doc['contract_id']).single();

    // 3. Fetch the agency signature
    final agencySig = await _c
        .from('agency_signatures')
        .select()
        .eq('id', doc['agency_signature_id'])
        .single();

    // 4. Download all signature images
    final agencyBytes = await _c.storage
        .from('agency-signatures')
        .download(agencySig['signature_image_path']);

    Uint8List? clientBytes;
    Uint8List? vendorWitnessBytes;
    Uint8List? buyerWitnessBytes;

    for (final s in signers as List) {
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

    // 5. Build the audit list
    final auditEntries = <SignerAuditInfo>[
      // Agency
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

    // 6. Find witness rows for the PDF input
    final clientRow =
    signers.firstWhere((s) => s['signer_role'] == 'client')
    as Map<String, dynamic>;
    final vendorWitnessRow =
    signers.firstWhere((s) => s['signer_role'] == 'vendor_witness')
    as Map<String, dynamic>;
    final buyerWitnessRow =
    signers.firstWhere((s) => s['signer_role'] == 'buyer_witness')
    as Map<String, dynamic>;

    // 7. Build the input for the PDF
    final client = contract['client'] as Map<String, dynamic>;
    final property = contract['property'] as Map<String, dynamic>;
    final agency = contract['agency'] as Map<String, dynamic>;

    final input = SaleAgreementInput(
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
      vendorWitnessSignedAtDisplay:
      vendorWitnessRow['signed_at'] != null
          ? _formatDate(DateTime.parse(
          vendorWitnessRow['signed_at'] as String))
          : null,

      buyerWitnessName: buyerWitnessRow['full_name'] as String?,
      buyerWitnessOccupation: buyerWitnessRow['occupation'] as String?,
      buyerWitnessAddress: buyerWitnessRow['address'] as String?,
      buyerWitnessSignatureImage: buyerWitnessBytes,
      buyerWitnessSignedAtDisplay:
      buyerWitnessRow['signed_at'] != null
          ? _formatDate(DateTime.parse(
          buyerWitnessRow['signed_at'] as String))
          : null,

      clientSignatureImage: clientBytes,
      clientSignedAtDisplay: clientRow['signed_at'] != null
          ? _formatDate(DateTime.parse(clientRow['signed_at'] as String))
          : null,
    );

    // 8. Render the PDF
    final pdfBytes = await SaleAgreementPdf.buildSignedWithAudit(
      input: input,
      auditEntries: auditEntries,
    );

    // 9. Upload to signed-documents bucket
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

    // 10. Update the document row
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
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

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

  /// Fetches signature progress for a contract.
  Future<SignatureProgress?> progressForContract(String contractId) async {
    final rows = await _c
        .from('v_document_signature_progress')
        .select()
        .eq('contract_id', contractId)
        .order('document_id', ascending: false)
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return SignatureProgress.fromMap(rows.first as Map<String, dynamic>);
  }
}

final documentsRepoProvider = Provider((_) => DocumentsRepository());

final contractSignatureProgressProvider =
FutureProvider.family<SignatureProgress?, String>(
        (ref, contractId) async {
      return ref.read(documentsRepoProvider).progressForContract(contractId);
    });