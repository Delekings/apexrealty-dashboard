// lib/data/repositories/recurring_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// Supported recurrence frequencies.
const kRecurringFrequencies = <String>[
  'weekly',
  'monthly',
  'quarterly',
  'yearly',
];

String recurringFrequencyLabel(String f) {
  switch (f) {
    case 'weekly':
      return 'Weekly';
    case 'quarterly':
      return 'Quarterly';
    case 'yearly':
      return 'Yearly';
    case 'monthly':
    default:
      return 'Monthly';
  }
}

class RecurringExpense {
  final String id;
  final String agencyId;
  final String category;
  final num amountNgn;
  final String? payee;
  final String? notes;
  final String frequency;
  final DateTime startDate;
  final DateTime nextDue;
  final bool active;

  RecurringExpense({
    required this.id,
    required this.agencyId,
    required this.category,
    required this.amountNgn,
    required this.frequency,
    required this.startDate,
    required this.nextDue,
    required this.active,
    this.payee,
    this.notes,
  });

  factory RecurringExpense.fromMap(Map<String, dynamic> m) => RecurringExpense(
        id: m['id'] as String,
        agencyId: m['agency_id'] as String,
        category: m['category'] as String,
        amountNgn: (m['amount_ngn'] as num?) ?? 0,
        payee: m['payee'] as String?,
        notes: m['notes'] as String?,
        frequency: m['frequency'] as String,
        startDate: DateTime.parse(m['start_date'] as String),
        nextDue: DateTime.parse(m['next_due'] as String),
        active: (m['active'] as bool?) ?? true,
      );

  String get frequencyLabel => recurringFrequencyLabel(frequency);
}

class RecurringRepository {
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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Add [n] months, clamping the day to the target month's last day
  /// (so 31 Jan + 1 month → 28/29 Feb, not 2/3 Mar).
  DateTime _addMonths(DateTime d, int n) {
    final total = d.month - 1 + n;
    final y = d.year + (total ~/ 12);
    final m = total % 12 + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final day = d.day <= lastDay ? d.day : lastDay;
    return DateTime(y, m, day);
  }

  DateTime _advance(DateTime d, String frequency) {
    switch (frequency) {
      case 'weekly':
        return d.add(const Duration(days: 7));
      case 'quarterly':
        return _addMonths(d, 3);
      case 'yearly':
        return _addMonths(d, 12);
      case 'monthly':
      default:
        return _addMonths(d, 1);
    }
  }

  Future<List<RecurringExpense>> list() async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return [];
    final rows = await _c
        .from('recurring_expenses')
        .select()
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => RecurringExpense.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String category,
    required num amountNgn,
    required String frequency,
    required DateTime startDate,
    String? payee,
    String? notes,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) throw Exception('No agency on profile');
    await _c.from('recurring_expenses').insert({
      'agency_id': agencyId,
      'created_by': _c.auth.currentUser?.id,
      'category': category,
      'amount_ngn': amountNgn,
      'payee': (payee == null || payee.trim().isEmpty) ? null : payee.trim(),
      'notes': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      'frequency': frequency,
      'start_date': _d(startDate),
      'next_due': _d(startDate),
      'active': true,
    });
  }

  Future<void> update(
    String id, {
    String? category,
    num? amountNgn,
    String? frequency,
    String? payee,
    String? notes,
    bool? active,
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (category != null) patch['category'] = category;
    if (amountNgn != null) patch['amount_ngn'] = amountNgn;
    if (frequency != null) patch['frequency'] = frequency;
    if (active != null) patch['active'] = active;
    if (payee != null) {
      patch['payee'] = payee.trim().isEmpty ? null : payee.trim();
    }
    if (notes != null) {
      patch['notes'] = notes.trim().isEmpty ? null : notes.trim();
    }
    await _c.from('recurring_expenses').update(patch).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('recurring_expenses').delete().eq('id', id);
  }

  /// Generates expense rows for every active rule whose next_due has passed,
  /// up to and including today, then advances each rule's next_due. Idempotent:
  /// each occurrence is created once. Returns the number of expense rows made.
  Future<int> materializeDue() async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return 0;
    final today = _dateOnly(DateTime.now());

    final rules = await _c
        .from('recurring_expenses')
        .select()
        .eq('agency_id', agencyId)
        .eq('active', true)
        .lte('next_due', _d(today));

    var generated = 0;
    for (final raw in rules as List) {
      final rule = RecurringExpense.fromMap(raw as Map<String, dynamic>);
      var due = _dateOnly(rule.nextDue);
      final toInsert = <Map<String, dynamic>>[];
      var guard = 0;
      while (!due.isAfter(today) && guard < 240) {
        toInsert.add({
          'agency_id': agencyId,
          'recorded_by': _c.auth.currentUser?.id,
          'category': rule.category,
          'amount_ngn': rule.amountNgn,
          'spent_on': _d(due),
          'payee': rule.payee,
          'notes': rule.notes,
        });
        due = _advance(due, rule.frequency);
        guard++;
      }
      if (toInsert.isNotEmpty) {
        await _c.from('expenses').insert(toInsert);
        await _c.from('recurring_expenses').update({
          'next_due': _d(due),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', rule.id);
        generated += toInsert.length;
      }
    }
    return generated;
  }
}
