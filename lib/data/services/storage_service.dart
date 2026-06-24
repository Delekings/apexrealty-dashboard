// lib/data/services/storage_service.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'supabase_service.dart';

class StorageService {
  static const _bucket = 'property-photos';
  static const _uuid = Uuid();

  /// Upload a single image file to the property-photos bucket.
  /// Path convention: <agency_id>/<property_id>/<random>.<ext>
  /// Returns the public URL.
  static Future<String> uploadPropertyPhoto({
    required String agencyId,
    required String propertyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final ext = _ext(filename);
    final path = '$agencyId/$propertyId/${_uuid.v4()}.$ext';

    await SupabaseService.client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _mimeFor(ext),
        upsert: false,
      ),
    );

    return SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
  }

  /// Upload an image/GIF for use in an email, into the public bucket under
  /// the agency's `email-assets/` prefix. Returns a public URL suitable for
  /// an email <img src> (email clients fetch it without auth).
  static Future<String> uploadEmailImage({
    required String agencyId,
    required Uint8List bytes,
    required String filename,
  }) async {
    final ext = _ext(filename);
    final path = '$agencyId/email-assets/${_uuid.v4()}.$ext';

    await SupabaseService.client.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _mimeFor(ext),
        upsert: false,
      ),
    );

    return SupabaseService.client.storage.from(_bucket).getPublicUrl(path);
  }

  /// Delete a photo by its full storage path (not the public URL).
  static Future<void> deletePhoto(String storagePath) async {
    await SupabaseService.client.storage.from(_bucket).remove([storagePath]);
  }

  /// Extract storage path from a public URL.
  /// Used when deleting — Supabase needs the path, not the URL.
  static String? pathFromUrl(String url) {
    final marker = '/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }

  static String _ext(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot == -1) return 'jpg';
    return filename.substring(dot + 1).toLowerCase();
  }

  static String _mimeFor(String ext) {
    switch (ext) {
      case 'png': return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif': return 'image/gif';
      default: return 'image/jpeg';
    }
  }
}