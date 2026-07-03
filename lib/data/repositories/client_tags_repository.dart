// lib/data/repositories/client_tags_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// A single user-created client tag (category).
class ClientTag {
  final String id;
  final String name;
  final String? color;

  const ClientTag({required this.id, required this.name, this.color});

  factory ClientTag.fromMap(Map<String, dynamic> m) => ClientTag(
        id: m['id'] as String,
        name: m['name'] as String,
        color: m['color'] as String?,
      );
}

/// All operations for client tags and their assignments.
///
/// RLS scopes every row to the caller's agency, so reads never need an explicit
/// agency filter. Writes DO need agency_id since the columns are NOT NULL and
/// the WITH CHECK policy verifies it matches the caller's agency.
class ClientTagsRepository {
  final SupabaseClient _c = SupabaseService.client;

  /// All tags for the current agency, alphabetical.
  Future<List<ClientTag>> listTags() async {
    final rows = await _c
        .from('client_tags')
        .select('id, name, color')
        .order('name', ascending: true);
    return (rows as List)
        .map((r) => ClientTag.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Create a new tag and return it. If a tag with the same name already exists
  /// for this agency (unique constraint), fetch and return the existing one so
  /// "create" is idempotent from the UI's perspective.
  Future<ClientTag> createTag({
    required String agencyId,
    required String name,
    String? color,
  }) async {
    final trimmed = name.trim();
    try {
      final row = await _c
          .from('client_tags')
          .insert({
            'agency_id': agencyId,
            'name': trimmed,
            if (color != null) 'color': color,
          })
          .select('id, name, color')
          .single();
      return ClientTag.fromMap(row);
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (tag name already exists for this agency).
      if (e.code == '23505') {
        final existing = await _c
            .from('client_tags')
            .select('id, name, color')
            .eq('agency_id', agencyId)
            .eq('name', trimmed)
            .single();
        return ClientTag.fromMap(existing);
      }
      rethrow;
    }
  }

  Future<void> deleteTag(String tagId) async {
    await _c.from('client_tags').delete().eq('id', tagId);
  }

  /// Tag ids currently assigned to a client.
  Future<List<String>> tagIdsForClient(String clientId) async {
    final rows = await _c
        .from('client_tag_assignments')
        .select('tag_id')
        .eq('client_id', clientId);
    return (rows as List).map((r) => r['tag_id'] as String).toList();
  }

  /// Replace a client's tag assignments with exactly [tagIds].
  /// Removes any existing assignments not in the list, adds any new ones.
  Future<void> setClientTags({
    required String agencyId,
    required String clientId,
    required List<String> tagIds,
  }) async {
    // Clear then re-insert — simplest correct approach for a small tag set.
    await _c
        .from('client_tag_assignments')
        .delete()
        .eq('client_id', clientId);

    if (tagIds.isEmpty) return;

    final rows = tagIds
        .toSet()
        .map((tid) => {
              'client_id': clientId,
              'tag_id': tid,
              'agency_id': agencyId,
            })
        .toList();
    await _c.from('client_tag_assignments').insert(rows);
  }

  /// Assign [tagIds] to many clients at once (used by CSV import — 2A).
  /// Skips duplicates via upsert-like ignore on the composite PK.
  Future<void> assignTagsToClients({
    required String agencyId,
    required List<String> clientIds,
    required List<String> tagIds,
  }) async {
    if (clientIds.isEmpty || tagIds.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (final cid in clientIds) {
      for (final tid in tagIds.toSet()) {
        rows.add({
          'client_id': cid,
          'tag_id': tid,
          'agency_id': agencyId,
        });
      }
    }
    // upsert with ignoreDuplicates so re-tagging is safe.
    await _c
        .from('client_tag_assignments')
        .upsert(rows, onConflict: 'client_id,tag_id', ignoreDuplicates: true);
  }
}
