// lib/data/repositories/income_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// Fixed, app-enforced sources for non-sale income (stored as text).
/// Keep stable — the P&L report groups on these exact strings.
const kIncomeSources = <String>[
  'Agency / agent fees',
  'Inspection fees',
  'Management commission',
  'Consultancy',
  'Rental income',
  'Document / processing fees',
  'Interest',
  'Refund',
  'Other',
];

class OtherIncome {
  final String id;
  final String agencyId;
  final String source;
  final num amountNgn;
  final DateTime receivedOn;
  final String? payer;
  final String? notes;
  final DateTime createdAt;

  OtherIncome({
    required this.id,
    required this.agencyId,
    required this.source,
    required this.amountNgn,
    required this.receivedOn,
    required this.createdAt,
    this.payer,
    this.notes,
  });

  factory OtherIncome.fromMap(Map<String, dynamic> m) => OtherIncome(
        id: m['id'] as String,
        agencyId: m['agency_id'] as String,
        source: m['source'] as String,
        amountNgn: (m['amount_ngn'] as num?) ?? 0,
        receivedOn: DateTime.parse(m['received_on'] as String),
        payer: m['payer'] as String?,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class IncomeRepository {
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

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Other income for the caller's agency, newest first. Optional date-range
  /// and source filters (used by later slices / the P&L report).
  Future<List<OtherIncome>> list({
    DateTime? from,
    DateTime? to,
    String? source,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];

    var q = _c.from('income_other').select().eq('agency_id', agencyId);
    if (from != null) q = q.gte('received_on', _d(from));
    if (to != null) q = q.lte('received_on', _d(to));
    if (source != null) q = q.eq('source', source);

    final rows = await q.order('received_on', ascending: false);
    return (rows as List)
        .map((r) => OtherIncome.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<OtherIncome> create({
    required String source,
    required num amountNgn,
    required DateTime receivedOn,
    String? payer,
    String? notes,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');

    final row = await _c
        .from('income_other')
        .insert({
          'agency_id': agencyId,
          'recorded_by': _c.auth.currentUser?.id,
          'source': source,
          'amount_ngn': amountNgn,
          'received_on': _d(receivedOn),
          'payer': (payer == null || payer.trim().isEmpty) ? null : payer.trim(),
          'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        })
        .select()
        .single();
    return OtherIncome.fromMap(row);
  }

  Future<OtherIncome> update(
    String id, {
    String? source,
    num? amountNgn,
    DateTime? receivedOn,
    String? payer,
    String? notes,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (source != null) patch['source'] = source;
    if (amountNgn != null) patch['amount_ngn'] = amountNgn;
    if (receivedOn != null) patch['received_on'] = _d(receivedOn);
    if (payer != null) {
      patch['payer'] = payer.trim().isEmpty ? null : payer.trim();
    }
    if (notes != null) {
      patch['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }

    final row = await _c
        .from('income_other')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return OtherIncome.fromMap(row);
  }

  Future<void> delete(String id) async {
    await _c.from('income_other').delete().eq('id', id);
  }
}
