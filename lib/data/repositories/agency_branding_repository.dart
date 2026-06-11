// lib/data/repositories/agency_branding_repository.dart
//
// Manages agency-level branding fields used in contract and receipt PDFs:
//   - common_seal_url      (storage path to optional common seal image)
//   - vendor_block_style   (how the vendor signature block renders on contracts)
//   - receipt_block_style  (how the signature block renders on receipts)
//
// Image storage uses the existing 'agency-signatures' bucket, same as
// individual director signatures. Permission to mutate is enforced by
// existing RLS — only agency admins can update their agency row.

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// Allowed values for vendor_block_style.
enum VendorBlockStyle { directorsOnly, sealOnly, directorsAndSeal }

/// Allowed values for receipt_block_style.
enum ReceiptBlockStyle { directorOnly, sealOnly, directorAndSeal }

String _vendorStyleToDb(VendorBlockStyle s) => switch (s) {
  VendorBlockStyle.directorsOnly => 'directors_only',
  VendorBlockStyle.sealOnly => 'seal_only',
  VendorBlockStyle.directorsAndSeal => 'directors_and_seal',
};

VendorBlockStyle _vendorStyleFromDb(String s) => switch (s) {
  'seal_only' => VendorBlockStyle.sealOnly,
  'directors_and_seal' => VendorBlockStyle.directorsAndSeal,
  _ => VendorBlockStyle.directorsOnly,
};

String _receiptStyleToDb(ReceiptBlockStyle s) => switch (s) {
  ReceiptBlockStyle.directorOnly => 'director_only',
  ReceiptBlockStyle.sealOnly => 'seal_only',
  ReceiptBlockStyle.directorAndSeal => 'director_and_seal',
};

ReceiptBlockStyle _receiptStyleFromDb(String s) => switch (s) {
  'seal_only' => ReceiptBlockStyle.sealOnly,
  'director_and_seal' => ReceiptBlockStyle.directorAndSeal,
  _ => ReceiptBlockStyle.directorOnly,
};

class AgencyBranding {
  final String agencyId;
  final String? commonSealUrl;
  final VendorBlockStyle vendorBlockStyle;
  final ReceiptBlockStyle receiptBlockStyle;

  AgencyBranding({
    required this.agencyId,
    required this.commonSealUrl,
    required this.vendorBlockStyle,
    required this.receiptBlockStyle,
  });

  factory AgencyBranding.fromMap(Map<String, dynamic> m) => AgencyBranding(
    agencyId: m['id'] as String,
    commonSealUrl: m['common_seal_url'] as String?,
    vendorBlockStyle:
    _vendorStyleFromDb(m['vendor_block_style'] as String? ?? 'directors_only'),
    receiptBlockStyle:
    _receiptStyleFromDb(m['receipt_block_style'] as String? ?? 'director_only'),
  );
}

class AgencyBrandingRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Reads the branding fields for an agency.
  Future<AgencyBranding> get(String agencyId) async {
    final row = await _c
        .from('agencies')
        .select('id, common_seal_url, vendor_block_style, receipt_block_style')
        .eq('id', agencyId)
        .single();
    return AgencyBranding.fromMap(row);
  }

  /// Updates the block-style settings without touching the seal image.
  Future<void> updateStyles({
    required String agencyId,
    required VendorBlockStyle vendorStyle,
    required ReceiptBlockStyle receiptStyle,
  }) async {
    await _c.from('agencies').update({
      'vendor_block_style': _vendorStyleToDb(vendorStyle),
      'receipt_block_style': _receiptStyleToDb(receiptStyle),
    }).eq('id', agencyId);
  }

  /// Uploads a new common seal image and saves its path.
  /// Replaces any existing seal (old file is removed best-effort).
  Future<String> uploadSeal({
    required String agencyId,
    required Uint8List imageBytes,
  }) async {
    // Remove old seal if there is one
    try {
      final current = await get(agencyId);
      if (current.commonSealUrl != null) {
        await _c.storage.from('agency-signatures').remove([current.commonSealUrl!]);
      }
    } catch (_) {
      // best-effort cleanup; never fail the upload because of it
    }

    final filename =
        'seal_${DateTime.now().millisecondsSinceEpoch}.png';
    final storagePath = '$agencyId/$filename';

    await _c.storage.from('agency-signatures').uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: const FileOptions(
        contentType: 'image/png',
        upsert: false,
      ),
    );

    await _c
        .from('agencies')
        .update({'common_seal_url': storagePath}).eq('id', agencyId);

    return storagePath;
  }

  /// Removes the common seal image entirely.
  Future<void> removeSeal(String agencyId) async {
    final current = await get(agencyId);
    if (current.commonSealUrl != null) {
      try {
        await _c.storage.from('agency-signatures').remove([current.commonSealUrl!]);
      } catch (_) {}
    }
    await _c
        .from('agencies')
        .update({'common_seal_url': null}).eq('id', agencyId);
  }

  /// Downloads seal image bytes for preview / PDF embedding.
  Future<Uint8List?> downloadSeal(String storagePath) async {
    try {
      return await _c.storage.from('agency-signatures').download(storagePath);
    } catch (_) {
      return null;
    }
  }
}

final agencyBrandingRepoProvider = Provider((_) => AgencyBrandingRepository());

final agencyBrandingProvider =
FutureProvider.family<AgencyBranding, String>((ref, agencyId) async {
  return ref.read(agencyBrandingRepoProvider).get(agencyId);
});