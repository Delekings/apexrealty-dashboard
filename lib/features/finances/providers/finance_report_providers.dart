import 'package:flutter_riverpod/legacy.dart';
// lib/features/finances/providers/finance_report_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/finance_report_repository.dart';

enum FinancePeriod { thisMonth, thisYear, allTime }

extension FinancePeriodX on FinancePeriod {
  String get label {
    switch (this) {
      case FinancePeriod.thisMonth:
        return 'This month';
      case FinancePeriod.thisYear:
        return 'This year';
      case FinancePeriod.allTime:
        return 'All time';
    }
  }

  /// Returns [from, toExclusive) for the period, anchored to today.
  ({DateTime from, DateTime toExclusive}) range() {
    final now = DateTime.now();
    switch (this) {
      case FinancePeriod.thisMonth:
        return (
          from: DateTime(now.year, now.month, 1),
          toExclusive: DateTime(now.year, now.month + 1, 1),
        );
      case FinancePeriod.thisYear:
        return (
          from: DateTime(now.year, 1, 1),
          toExclusive: DateTime(now.year + 1, 1, 1),
        );
      case FinancePeriod.allTime:
        return (
          from: DateTime(2015, 1, 1),
          toExclusive: DateTime(now.year + 1, 1, 1),
        );
    }
  }
}

final financeReportRepoProvider = Provider((_) => FinanceReportRepository());

final financePeriodProvider =
    StateProvider<FinancePeriod>((_) => FinancePeriod.thisMonth);

final financeSummaryProvider =
    FutureProvider.autoDispose<FinanceSummary>((ref) async {
  final period = ref.watch(financePeriodProvider);
  final r = period.range();
  return ref
      .read(financeReportRepoProvider)
      .summary(from: r.from, toExclusive: r.toExclusive);
});
