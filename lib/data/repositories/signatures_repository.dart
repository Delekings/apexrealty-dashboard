// lib/data/repositories/signatures_repository.dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class AgencySignature {
  final String id;
  final String agencyId;
  final String label;
  final String signerName;
  final String? signerTitle;
  final String signatureImagePath;
  final String method;
  final bool isDefault;
  final bool isReceiptSigner;
  final DateTime createdAt;
  AgencySignature({
    required this.id,
    required this.agencyId,
    required this.label,
    required this.signerName,
    this.signerTitle,
    required this.signatureImagePath,
    required this.method,
    required this.isDefault,
    required this.isReceiptSigner,
    required this.createdAt,
  });

  factory AgencySignature.fromMap(Map<String, dynamic> m) => AgencySignature(
    id: m['id'] as String,
    agencyId: m['agency_id'] as String,
    label: m['label'] as String,
    signerName: m['signer_name'] as String,
    signerTitle: m['signer_title'] as String?,
    signatureImagePath: m['signature_image_path'] as String,
    method: m['method'] as String,
    isDefault: m['is_default'] as bool,
    isReceiptSigner: (m['is_receipt_signer'] as bool?) ?? false,
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}

class SignaturesRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<List<AgencySignature>> list(String agencyId) async {
    final rows = await _c
        .from('agency_signatures')
        .select()
        .eq('agency_id', agencyId)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AgencySignature.fromMap(r))
        .toList();
  }

  Future<AgencySignature> create({
    required String agencyId,
    required String label,
    required String signerName,
    String? signerTitle,
    required Uint8List imageBytes,
    required String method, // 'drawn' or 'uploaded'
    bool isDefault = false,
    bool isReceiptSigner = false,
  }) async {
    // 1. Upload image to agency-signatures bucket
    //    Path: <agency_id>/<random>.png
    final filename =
        '${DateTime.now().millisecondsSinceEpoch}_${_randomSuffix()}.png';
    final storagePath = '$agencyId/$filename';

    await _c.storage.from('agency-signatures').uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: const FileOptions(
        contentType: 'image/png',
        upsert: false,
      ),
    );

    // 2. If isDefault, unset any existing default first
    // 2a. If isDefault, unset any existing default first
    if (isDefault) {
      await _c
          .from('agency_signatures')
          .update({'is_default': false})
          .eq('agency_id', agencyId)
          .eq('is_default', true);
    }
    // 2b. If isReceiptSigner, unset any existing receipt signer first
    if (isReceiptSigner) {
      await _c
          .from('agency_signatures')
          .update({'is_receipt_signer': false})
          .eq('agency_id', agencyId)
          .eq('is_receipt_signer', true);
    }
    // 3. Insert metadata row
    final row = await _c.from('agency_signatures').insert({
      'agency_id': agencyId,
      'label': label,
      'signer_name': signerName,
      'signer_title': signerTitle,
      'signature_image_path': storagePath,
      'method': method,
      'is_default': isDefault,
      'is_receipt_signer': isReceiptSigner,
    }).select().single();
    return AgencySignature.fromMap(row);
  }

  Future<void> setDefault(String agencyId, String signatureId) async {
    // Clear current default
    await _c
        .from('agency_signatures')
        .update({'is_default': false})
        .eq('agency_id', agencyId)
        .eq('is_default', true);
    // Set new one
    await _c
        .from('agency_signatures')
        .update({'is_default': true})
        .eq('id', signatureId);
  }

  Future<void> setReceiptSigner(String agencyId, String signatureId) async {
    // Clear current receipt signer
    await _c
        .from('agency_signatures')
        .update({'is_receipt_signer': false})
        .eq('agency_id', agencyId)
        .eq('is_receipt_signer', true);
    // Set new one
    await _c
        .from('agency_signatures')
        .update({'is_receipt_signer': true})
        .eq('id', signatureId);
  }

  Future<void> delete(String signatureId) async {
    // Fetch first to know storage path
    final row = await _c
        .from('agency_signatures')
        .select('signature_image_path')
        .eq('id', signatureId)
        .single();
    final path = row['signature_image_path'] as String;

    await _c.from('agency_signatures').delete().eq('id', signatureId);

    // Delete storage object (best-effort)
    try {
      await _c.storage.from('agency-signatures').remove([path]);
    } catch (_) {}
  }

  /// Downloads signature image bytes (for embedding in PDF).
  Future<Uint8List> downloadImage(String storagePath) async {
    return await _c.storage.from('agency-signatures').download(storagePath);
  }

  String _randomSuffix() {
    final r =
    DateTime.now().microsecondsSinceEpoch.toRadixString(36).padLeft(8, '0');
    return r.substring(r.length - 8);
  }
}

final signaturesRepoProvider = Provider((_) => SignaturesRepository());

final agencySignaturesProvider =
FutureProvider.family<List<AgencySignature>, String>(
        (ref, agencyId) async {
      return ref.read(signaturesRepoProvider).list(agencyId);
    });