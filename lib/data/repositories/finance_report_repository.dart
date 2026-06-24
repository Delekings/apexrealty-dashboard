// lib/data/repositories/finance_report_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

/// A profit-&-loss summary for one period.
///
///   total income = sale payments + other income
///   net          = total income − expenses
class FinanceSummary {
  /// Sum of sale payments (public.payments) in the period.
  final num saleIncome;

  /// Other income (public.income_other) grouped by source.
  final Map<String, num> otherIncomeBySource;

  /// Expenses (public.expenses) grouped by category.
  final Map<String, num> expensesByCategory;

  const FinanceSummary({
    required this.saleIncome,
    required this.otherIncomeBySource,
    required this.expensesByCategory,
  });

  static const empty = FinanceSummary(
    saleIncome: 0,
    otherIncomeBySource: {},
    expensesByCategory: {},
  );

  num get otherIncomeTotal =>
      otherIncomeBySource.values.fold<num>(0, (a, b) => a + b);

  num get expensesTotal =>
      expensesByCategory.values.fold<num>(0, (a, b) => a + b);

  num get totalIncome => saleIncome + otherIncomeTotal;

  num get net => totalIncome - expensesTotal;

  bool get isEmpty =>
      saleIncome == 0 &&
      otherIncomeBySource.isEmpty &&
      expensesByCategory.isEmpty;
}

class FinanceReportRepository {
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

  /// Aggregates income and expenses for [from, toExclusive).
  /// [from] is inclusive; [toExclusive] is the first instant AFTER the period.
  Future<FinanceSummary> summary({
    required DateTime from,
    required DateTime toExclusive,
  }) async {
    final agencyId = await _myAgencyId();
    if (agencyId == null) return FinanceSummary.empty;

    // Sale income — payments.paid_at is a timestamptz.
    final payRows = await _c
        .from('payments')
        .select('amount_ngn')
        .eq('agency_id', agencyId)
        .gte('paid_at', from.toUtc().toIso8601String())
        .lt('paid_at', toExclusive.toUtc().toIso8601String());
    num saleIncome = 0;
    for (final r in payRows as List) {
      saleIncome += (r['amount_ngn'] as num?) ?? 0;
    }

    // Other income — received_on is a date.
    final incRows = await _c
        .from('income_other')
        .select('amount_ngn, source')
        .eq('agency_id', agencyId)
        .gte('received_on', _d(from))
        .lt('received_on', _d(toExclusive));
    final otherBySource = <String, num>{};
    for (final r in incRows as List) {
      final s = (r['source'] as String?) ?? 'Other';
      otherBySource[s] = (otherBySource[s] ?? 0) + ((r['amount_ngn'] as num?) ?? 0);
    }

    // Expenses — spent_on is a date.
    final expRows = await _c
        .from('expenses')
        .select('amount_ngn, category')
        .eq('agency_id', agencyId)
        .gte('spent_on', _d(from))
        .lt('spent_on', _d(toExclusive));
    final byCat = <String, num>{};
    for (final r in expRows as List) {
      final cat = (r['category'] as String?) ?? 'Other';
      byCat[cat] = (byCat[cat] ?? 0) + ((r['amount_ngn'] as num?) ?? 0);
    }

    return FinanceSummary(
      saleIncome: saleIncome,
      otherIncomeBySource: otherBySource,
      expensesByCategory: byCat,
    );
  }
}
