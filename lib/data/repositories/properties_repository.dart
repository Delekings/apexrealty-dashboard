// lib/data/repositories/properties_repository.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class PropertiesRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// Paginated list with optional search and status filter.
  Future<PropertiesPage> list({
    String? search,
    PropertyStatus? status,
    int page = 0,
    int pageSize = 12,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var filterQuery = _c.from('properties').select();

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      filterQuery = filterQuery.or(
        'title.ilike.%$s%,location.ilike.%$s%,state.ilike.%$s%',
      );
    }
    if (status != null) {
      filterQuery = filterQuery.eq('status', _statusToDb(status));
    }

    final total = await _countQuery(search: search, status: status);

    final rows = await filterQuery
        .order('created_at', ascending: false)
        .range(from, to);

    return PropertiesPage(
      items: (rows as List)
          .map((r) => Property.fromMap(r as Map<String, dynamic>))
          .toList(),
      total: total,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<int> _countQuery({String? search, PropertyStatus? status}) async {
    var q = _c.from('properties').select('id');
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      q = q.or('title.ilike.%$s%,location.ilike.%$s%,state.ilike.%$s%');
    }
    if (status != null) {
      q = q.eq('status', _statusToDb(status));
    }
    final res = await q.count(CountOption.exact);
    return res.count;
  }

  Future<Property> get(String id) async {
    final row =
    await _c.from('properties').select().eq('id', id).single();
    return Property.fromMap(row);
  }

  /// Create a new property. Returns the new id.
  /// agency_id is required (we pass from the caller).
  Future<String> create({
    required String agencyId,
    required String title,
    required PropertyType type,
    required String location,
    required String state,
    required num basePrice,
    required int totalUnits,
    String? description,
    String? lga,
    num? sizeSqm,
  }) async {
    final res = await _c
        .from('properties')
        .insert({
      'agency_id': agencyId,
      'title': title.trim(),
      'property_type': type.name,
      'status': 'available',
      'location': location.trim(),
      'state': state,
      if (lga != null && lga.trim().isNotEmpty) 'lga': lga.trim(),
      if (sizeSqm != null) 'size_sqm': sizeSqm,
      'base_price_ngn': basePrice,
      'total_units': totalUnits,
      'available_units': totalUnits,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
    })
        .select('id')
        .single();

    final newId = res['id'] as String;

    await _c.from('activity_log').insert({
      'agency_id': agencyId,
      'entity_type': 'property',
      'entity_id': newId,
      'action': 'created',
      'description': 'Property "$title" added',
    });

    return newId;
  }

  /// Upload one or more photos to a property. Updates cover_image_url
  /// (if not yet set) and appends to gallery_urls.
  Future<List<String>> uploadPhotos({
    required String agencyId,
    required String propertyId,
    required List<({Uint8List bytes, String filename})> files,
  }) async {
    final urls = <String>[];
    for (final f in files) {
      final url = await StorageService.uploadPropertyPhoto(
        agencyId: agencyId,
        propertyId: propertyId,
        bytes: f.bytes,
        filename: f.filename,
      );
      urls.add(url);
    }

    // Get current property to see what's there
    final current = await _c
        .from('properties')
        .select('cover_image_url, gallery_urls')
        .eq('id', propertyId)
        .single();

    final existingGallery =
        (current['gallery_urls'] as List?)?.cast<String>() ?? <String>[];
    final newGallery = [...existingGallery, ...urls];

    await _c.from('properties').update({
      if (current['cover_image_url'] == null) 'cover_image_url': urls.first,
      'gallery_urls': newGallery,
    }).eq('id', propertyId);

    return urls;
  }

  Future<void> deletePhoto({
    required String propertyId,
    required String url,
  }) async {
    // Remove from storage
    final path = StorageService.pathFromUrl(url);
    if (path != null) {
      await StorageService.deletePhoto(path);
    }

    // Remove from property record
    final current = await _c
        .from('properties')
        .select('cover_image_url, gallery_urls')
        .eq('id', propertyId)
        .single();

    final gallery =
        (current['gallery_urls'] as List?)?.cast<String>() ?? <String>[];
    gallery.remove(url);

    final newCover = current['cover_image_url'] == url
        ? (gallery.isEmpty ? null : gallery.first)
        : current['cover_image_url'];

    await _c.from('properties').update({
      'cover_image_url': newCover,
      'gallery_urls': gallery,
    }).eq('id', propertyId);
  }

  Future<void> update(String id, Map<String, dynamic> patch) async {
    await _c.from('properties').update(patch).eq('id', id);
  }

  String _statusToDb(PropertyStatus s) => switch (s) {
    PropertyStatus.available => 'available',
    PropertyStatus.reserved => 'reserved',
    PropertyStatus.partiallySold => 'partially_sold',
    PropertyStatus.soldOut => 'sold_out',
    PropertyStatus.inactive => 'inactive',
  };
}

class PropertiesPage {
  final List<Property> items;
  final int total;
  final int page;
  final int pageSize;
  PropertiesPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  int get totalPages =>
      pageSize == 0 ? 0 : (total / pageSize).ceil().clamp(0, 1 << 30);
  bool get hasNext => (page + 1) < totalPages;
  bool get hasPrev => page > 0;
}