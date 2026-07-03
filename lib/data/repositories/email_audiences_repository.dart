// lib/data/repositories/email_audiences_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// A saved, reusable campaign audience: a named wrapper around a recipient
/// filter (the same JSON shape used by [EmailRepository.sendBulk] /
/// previewRecipientCount).
class EmailAudience {
  final String id;
  final String agencyId;
  final String name;
  final String? description;
  final Map<String, dynamic> filter;
  final DateTime createdAt;

  EmailAudience({
    required this.id,
    required this.agencyId,
    required this.name,
    required this.filter,
    required this.createdAt,
    this.description,
  });

  factory EmailAudience.fromMap(Map<String, dynamic> m) => EmailAudience(
        id: m['id'] as String,
        agencyId: m['agency_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        filter: (m['filter'] as Map?)?.cast<String, dynamic>() ??
            const {'type': 'all'},
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  /// The filter's recipient `type` (all / by_state / has_active_contract /
  /// has_overdue), defaulting to 'all' for safety.
  String get filterType => (filter['type'] as String?) ?? 'all';

  /// A human-readable one-line summary of who this audience targets.
  String get filterLabel => describeFilter(filter);

  /// Static so callers (dialogs, pickers) can summarise a raw filter map too.
  static String describeFilter(Map<String, dynamic> filter) {
    switch (filter['type'] as String?) {
      case 'by_state':
        final states =
            (filter['states'] as List?)?.cast<String>() ?? const [];
        if (states.isEmpty) return 'Clients by state';
        return 'Clients in ${states.join(', ')}';
      case 'has_active_contract':
        return 'Clients with an active contract';
      case 'has_overdue':
        return 'Clients with an overdue payment';
      case 'by_tag':
        final tagIds = (filter['tagIds'] as List?)?.cast<String>() ?? const [];
        if (tagIds.isEmpty) return 'Clients by tag';
        return 'Clients with ${tagIds.length} tag(s)';
      case 'all':
      default:
        return 'All subscribed clients';
    }
  }
}

class EmailAudiencesRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<String?> _myAgencyId() async {
    final userId = _c.auth.currentUser?.id;
    if (userId == null) return null;
    final r = await _c
        .from('profiles')
        .select('agency_id')
        .eq('id', userId)
        .maybeSingle();
    return r?['agency_id'] as String?;
  }

  /// All saved audiences for the caller's agency, newest first.
  Future<List<EmailAudience>> list() async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];

    final rows = await _c
        .from('email_audiences')
        .select()
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => EmailAudience.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<EmailAudience> create({
    required String name,
    String? description,
    required Map<String, dynamic> filter,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');

    final row = await _c
        .from('email_audiences')
        .insert({
          'agency_id': agencyId,
          'created_by': _c.auth.currentUser?.id,
          'name': name.trim(),
          'description':
              (description == null || description.trim().isEmpty)
                  ? null
                  : description.trim(),
          'filter': filter,
        })
        .select()
        .single();

    return EmailAudience.fromMap(row);
  }

  Future<EmailAudience> update(
    String id, {
    String? name,
    String? description,
    Map<String, dynamic>? filter,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null) patch['name'] = name.trim();
    if (description != null) {
      patch['description'] =
          description.trim().isEmpty ? null : description.trim();
    }
    if (filter != null) patch['filter'] = filter;

    final row = await _c
        .from('email_audiences')
        .update(patch)
        .eq('id', id)
        .select()
        .single();

    return EmailAudience.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _c.from('email_audiences').delete().eq('id', id);
  }
}
