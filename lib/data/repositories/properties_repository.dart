// lib/data/repositories/properties_repository.dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class PropertiesRepository {
  final SupabaseClient _c = SupabaseService.client;

  // ============================================================
  // Listing & lookup
  // ============================================================

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

  // ============================================================
  // Unit types (multi-unit inventory)
  // ============================================================

  /// Fetch all unit types for a property with availability stats from
  /// the v_unit_type_availability view.
  Future<List<PropertyUnitType>> getUnitTypes(String propertyId) async {
    // Fetch both tables in parallel, then merge.
    final results = await Future.wait([
      _c
          .from('property_unit_types')
          .select()
          .eq('property_id', propertyId)
          .order('display_order'),
      _c
          .from('v_unit_type_availability')
          .select('unit_type_id, reserved_units, sold_units, available_units')
          .eq('property_id', propertyId),
    ]);

    final unitRows = (results[0] as List);
    final availRows = (results[1] as List);

    // Build a quick lookup of availability by unit_type_id
    final availMap = <String, Map<String, dynamic>>{};
    for (final a in availRows) {
      final ma = a as Map<String, dynamic>;
      availMap[ma['unit_type_id'] as String] = ma;
    }

    final result = <PropertyUnitType>[];
    for (final r in unitRows) {
      final m = Map<String, dynamic>.from(r as Map);
      final avail = availMap[m['id'] as String];
      if (avail != null) {
        m['reserved_units'] = avail['reserved_units'];
        m['sold_units'] = avail['sold_units'];
        m['available_units'] = avail['available_units'];
      }
      result.add(PropertyUnitType.fromMap(m));
    }
    return result;
  }

  /// Fetch a single unit type by id, with availability stats.
  Future<PropertyUnitType?> getUnitTypeById(String unitTypeId) async {
    final row = await _c
        .from('property_unit_types')
        .select()
        .eq('id', unitTypeId)
        .maybeSingle();
    if (row == null) return null;

    final avail = await _c
        .from('v_unit_type_availability')
        .select('reserved_units, sold_units, available_units')
        .eq('unit_type_id', unitTypeId)
        .maybeSingle();

    final m = Map<String, dynamic>.from(row);
    if (avail != null) {
      m['reserved_units'] = avail['reserved_units'];
      m['sold_units'] = avail['sold_units'];
      m['available_units'] = avail['available_units'];
    }
    return PropertyUnitType.fromMap(m);
  }

  /// Insert a property + its unit types in sequence. If unit-type insert
  /// fails, the property is cleaned up so we don't end up with orphaned
  /// properties that have no inventory.
  Future<String> createPropertyWithUnits({
    required String agencyId,
    required String title,
    required String state,
    required String? lga,
    required String location,
    String? description,
    String? coverImageUrl,
    List<String> gallery = const [],
    PropertyType type = PropertyType.land,
    required List<UnitTypeDraft> unitTypes,
  }) async {
    if (unitTypes.isEmpty) {
      throw Exception('Add at least one unit type');
    }

    // Aggregate totals for the legacy columns (kept for backward compat
    // with code that still reads properties.total_units / available_units).
    final totalUnits =
    unitTypes.fold<int>(0, (s, u) => s + u.totalUnits);
    final minPrice = unitTypes
        .map((u) => u.basePriceNgn)
        .reduce((a, b) => a < b ? a : b);

    // 1. Insert the property
    final propRow = await _c
        .from('properties')
        .insert({
      'agency_id': agencyId,
      'title': title.trim(),
      'property_type': type.name,
      'status': 'available',
      'state': state,
      'location': location.trim(),
      if (lga != null && lga.trim().isNotEmpty) 'lga': lga.trim(),
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (gallery.isNotEmpty) 'gallery_urls': gallery,
      // Legacy aggregate columns (kept synced for the moment)
      'base_price_ngn': minPrice,
      'total_units': totalUnits,
      'available_units': totalUnits,
    })
        .select('id')
        .single();

    final propertyId = propRow['id'] as String;

    // 2. Insert all unit types
    try {
      final unitRows = <Map<String, dynamic>>[];
      for (var i = 0; i < unitTypes.length; i++) {
        final u = unitTypes[i];
        unitRows.add({
          'agency_id': agencyId,
          'property_id': propertyId,
          'title': u.title,
          if (u.description != null) 'description': u.description,
          if (u.sizeSqm != null) 'size_sqm': u.sizeSqm,
          'base_price_ngn': u.basePriceNgn,
          'total_units': u.totalUnits,
          'display_order': i,
        });
      }
      await _c.from('property_unit_types').insert(unitRows);
    } catch (e) {
      // Best-effort rollback so we don't orphan the property
      try {
        await _c.from('properties').delete().eq('id', propertyId);
      } catch (_) {
        // Swallow — we'll surface the original error below
      }
      rethrow;
    }

    await _c.from('activity_log').insert({
      'agency_id': agencyId,
      'entity_type': 'property',
      'entity_id': propertyId,
      'action': 'created',
      'description':
      'Property "$title" added with ${unitTypes.length} unit type(s)',
    });

    return propertyId;
  }

  // ============================================================
  // Legacy create (kept so existing call sites still compile)
  //
  // New code should use createPropertyWithUnits.
  // ============================================================

  /// Create a new property without unit types.
  ///
  /// **Deprecated:** use [createPropertyWithUnits] instead. This is kept
  /// only so older screens still compile; new properties created this
  /// way will not show up correctly in the unit-inventory UI.
  @Deprecated('Use createPropertyWithUnits instead')
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

  // ============================================================
  // Photos
  // ============================================================

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

// ============================================================
// Helpers
// ============================================================

/// A unit-type entry being passed to [PropertiesRepository.createPropertyWithUnits].
/// This is a plain class (not a record) so it can be referenced from
/// the form screen cleanly.
class UnitTypeDraft {
  final String title;
  final String? description;
  final num? sizeSqm;
  final num basePriceNgn;
  final int totalUnits;

  UnitTypeDraft({
    required this.title,
    required this.basePriceNgn,
    required this.totalUnits,
    this.description,
    this.sizeSqm,
  });
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