// lib/data/repositories/signing_repository.dart
//
// Repository used by the PUBLIC signing page. All RPCs here are
// SECURITY DEFINER on the database side, gated by the long random
// token. The client is anonymous (no auth.uid()) during signing.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class SigningContext {
  final String signerId;
  final String documentId;
  final String signerRole;          // client | vendor_witness | buyer_witness
  final int signerOrder;
  final String? signerFullName;
  final String? signerEmail;
  final String signerStatus;        // awaiting_signer | otp_verified | signed
  final String docStatus;
  final String docType;
  final String? currentPdfPath;
  final String agencyName;
  final String? agencyLogoUrl;
  final String? contractNo;
  final num? contractTotalNgn;
  final String? propertyTitle;
  final String? propertyLocation;
  final String? propertyState;
  final String? clientFullName;

  SigningContext({
    required this.signerId,
    required this.documentId,
    required this.signerRole,
    required this.signerOrder,
    this.signerFullName,
    this.signerEmail,
    required this.signerStatus,
    required this.docStatus,
    required this.docType,
    this.currentPdfPath,
    required this.agencyName,
    this.agencyLogoUrl,
    this.contractNo,
    this.contractTotalNgn,
    this.propertyTitle,
    this.propertyLocation,
    this.propertyState,
    this.clientFullName,
  });

  factory SigningContext.fromMap(Map<String, dynamic> m) => SigningContext(
    signerId: m['signer_id'] as String,
    documentId: m['document_id'] as String,
    signerRole: m['signer_role'] as String,
    signerOrder: m['signer_order'] as int,
    signerFullName: m['signer_full_name'] as String?,
    signerEmail: m['signer_email'] as String?,
    signerStatus: m['signer_status'] as String,
    docStatus: m['doc_status'] as String,
    docType: m['doc_type'] as String,
    currentPdfPath: m['current_pdf_path'] as String?,
    agencyName: m['agency_name'] as String,
    agencyLogoUrl: (m['agency_logo_url'] as String?)?.isNotEmpty == true
        ? m['agency_logo_url'] as String?
        : null,
    contractNo: m['contract_no'] as String?,
    contractTotalNgn: m['contract_total_ngn'] as num?,
    propertyTitle: m['property_title'] as String?,
    propertyLocation: m['property_location'] as String?,
    propertyState: m['property_state'] as String?,
    clientFullName: m['client_full_name'] as String?,
  );

  String get roleLabel => switch (signerRole) {
    'client' => 'Purchaser',
    'vendor_witness' => "Vendor's witness",
    'buyer_witness' => "Buyer's witness",
    _ => signerRole,
  };
}

class OtpRequestResult {
  final String email;
  final String maskedEmail;
  final String devCode;     // dev only — production would email it
  final DateTime expiresAt;
  OtpRequestResult({
    required this.email,
    required this.maskedEmail,
    required this.devCode,
    required this.expiresAt,
  });
  factory OtpRequestResult.fromMap(Map<String, dynamic> m) => OtpRequestResult(
    email: m['email'] as String,
    maskedEmail: m['masked_email'] as String,
    devCode: m['dev_code'] as String,
    expiresAt: DateTime.parse(m['expires_at'] as String),
  );
}

class SignResult {
  final String signerId;
  final String documentId;
  final String? nextSignerRole;
  final String? nextSignerEmail;
  final String? nextSignerToken;
  final bool needsBuyerWitness;

  SignResult({
    required this.signerId,
    required this.documentId,
    this.nextSignerRole,
    this.nextSignerEmail,
    this.nextSignerToken,
    this.needsBuyerWitness = false,
  });

  factory SignResult.fromMap(Map<String, dynamic> m) => SignResult(
    signerId: m['out_signer_id'] as String,
    documentId: m['out_document_id'] as String,
    nextSignerRole: (m['next_signer_role'] as String?)?.isEmpty == true
        ? null
        : m['next_signer_role'] as String?,
    nextSignerEmail: (m['next_signer_email'] as String?)?.isEmpty == true
        ? null
        : m['next_signer_email'] as String?,
    nextSignerToken: (m['next_signer_token'] as String?)?.isEmpty == true
        ? null
        : m['next_signer_token'] as String?,
    needsBuyerWitness: m['needs_buyer_witness'] as bool? ?? false,
  );

  bool get isLastSigner => nextSignerRole == null || nextSignerRole!.isEmpty;
}

class SigningRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<SigningContext?> getContext(String token) async {
    final rows = await _c.rpc('get_signing_context', params: {
      'p_token': token,
    });
    if (rows is List && rows.isNotEmpty) {
      return SigningContext.fromMap(rows.first as Map<String, dynamic>);
    }
    return null;
  }

  Future<OtpRequestResult> requestOtp(String token) async {
    final rows = await _c.rpc('request_signer_otp', params: {
      'p_token': token,
    });
    if (rows is List && rows.isNotEmpty) {
      return OtpRequestResult.fromMap(rows.first as Map<String, dynamic>);
    }
    throw Exception('Could not request code');
  }

  /// Returns true if the OTP matched, false otherwise.
  Future<bool> verifyOtp(String token, String code) async {
    final rows = await _c.rpc('verify_signer_otp', params: {
      'p_token': token,
      'p_code': code,
    });
    if (rows is List && rows.isNotEmpty) {
      final m = rows.first as Map<String, dynamic>;
      return m['verified'] == true;
    }
    return false;
  }

  /// Uploads the signer's signature image to storage and returns the path.
  Future<String> uploadSignature({
    required String documentId,
    required String signerRole,
    required Uint8List bytes,
  }) async {
    // We can't use current_agency_id() here (we're anonymous), so the
    // bucket policy lets anon write under any prefix; the agency reads
    // are gated by their own RLS via agency_id folder structure.
    // We use the document_id as a unique prefix so signed URLs work cleanly.
    final filename =
        '${signerRole}_${DateTime.now().millisecondsSinceEpoch}.png';
    final path = '$documentId/$filename';

    await _c.storage.from('signer-signatures').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/png',
        upsert: true,
      ),
    );
    return path;
  }

  Future<SignResult> recordSignature({
    required String token,
    required String signaturePath,
    required String signatureMethod, // drawn | typed | uploaded
    String? occupation,
    String? address,
    String? buyerWitnessFullName,
    String? buyerWitnessEmail,
  }) async {
    final rows = await _c.rpc('record_signer_signature', params: {
      'p_token': token,
      'p_signature_path': signaturePath,
      'p_signature_method': signatureMethod,
      'p_occupation': occupation,
      'p_address': address,
      'p_buyer_witness_full_name': buyerWitnessFullName,
      'p_buyer_witness_email': buyerWitnessEmail,
      'p_ip': null,         // browser cannot reliably know its own IP
      'p_user_agent': null,
    });
    if (rows is List && rows.isNotEmpty) {
      return SignResult.fromMap(rows.first as Map<String, dynamic>);
    }
    throw Exception('Could not record signature');
  }

  /// Generates a signed URL to download a PDF stored in unsigned-documents
  /// or signed-documents. We need this so the signing page can preview
  /// the document even though the bucket is private.
  Future<String> getSignedPdfUrl(String storagePath, {bool signed = false}) async {
    final bucket = signed ? 'signed-documents' : 'unsigned-documents';
    return await _c.storage.from(bucket).createSignedUrl(storagePath, 3600);
  }
}

final signingRepoProvider = Provider((_) => SigningRepository());

final signingContextProvider =
FutureProvider.family<SigningContext?, String>((ref, token) async {
  return ref.read(signingRepoProvider).getContext(token);
});