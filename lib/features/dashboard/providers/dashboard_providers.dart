// lib/features/dashboard/providers/dashboard_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';

class DashboardData {
  final DashboardStats stats;
  final List<MonthlyRevenue> monthlyRevenue;
  final List<ActivityEntry> recentActivity;
  final PaymentStatusBreakdown paymentStatus;

  DashboardData({
    required this.stats,
    required this.monthlyRevenue,
    required this.recentActivity,
    required this.paymentStatus,
  });
}

class MonthlyRevenue {
  final String label;
  final num amount;
  MonthlyRevenue(this.label, this.amount);
}

class PaymentStatusBreakdown {
  final int onTrack;
  final int dueSoon;
  final int overdue;
  PaymentStatusBreakdown({
    required this.onTrack,
    required this.dueSoon,
    required this.overdue,
  });
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final c = SupabaseService.client;
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final lastMonthStart = DateTime(now.year, now.month - 1, 1);

  final results = await Future.wait<dynamic>([
    c.from('clients').count(CountOption.exact),
    c.from('clients')
        .select('id')
        .gte('created_at', monthStart.toIso8601String())
        .count(CountOption.exact),
    c.from('payments')
        .select('amount_ngn')
        .gte('paid_at', monthStart.toIso8601String()),
    c.from('payments')
        .select('amount_ngn')
        .gte('paid_at', lastMonthStart.toIso8601String())
        .lt('paid_at', monthStart.toIso8601String()),
    c.from('installments').select('id, due_date').eq('status', 'overdue'),
    c.from('properties')
        .select('id')
        .neq('status', 'inactive')
        .count(CountOption.exact),
    c.from('properties')
        .select('id')
        .eq('status', 'sold_out')
        .count(CountOption.exact),
    c.rpc('monthly_revenue_last_6'),
    c
        .from('activity_log')
        .select('*, actor:profiles(full_name)')
        .order('created_at', ascending: false)
        .limit(6),
    c.from('installments').select('status'),
  ]);

  int countOf(dynamic r) {
    try {
      // supabase_flutter v2: count queries return a record with a `count` field
      return (r.count ?? 0) as int;
    } catch (_) {
      if (r is Map && r['count'] is int) return r['count'] as int;
      return 0;
    }
  }

  num sumAmounts(List rows) =>
      rows.fold<num>(0, (sum, r) => sum + ((r['amount_ngn'] as num?) ?? 0));

  final totalClients = countOf(results[0]);
  final newClients = countOf(results[1]);
  final revenueThisMonth = sumAmounts(results[2] as List);
  final revenueLastMonth = sumAmounts(results[3] as List);

  final overdueRows = results[4] as List;
  final overdueCount = overdueRows.length;
  final newOverdueToday = overdueRows.where((r) {
    final d = DateTime.tryParse(r['due_date'] as String? ?? '');
    return d != null &&
        d.year == now.year && d.month == now.month && d.day == now.day;
  }).length;

  final activeProps = countOf(results[5]);
  final soldOut = countOf(results[6]);

  final revSeries = (results[7] as List?) ?? [];
  final monthlyRev = revSeries
      .map((r) => MonthlyRevenue(
          (r['month_label'] ?? '') as String,
          (r['total_ngn'] as num?) ?? 0))
      .toList();

  final activity = (results[8] as List)
      .map((r) => ActivityEntry.fromMap(r as Map<String, dynamic>))
      .toList();

  int onTrack = 0, dueSoon = 0, overdue = 0;
  for (final r in results[9] as List) {
    switch (r['status']) {
      case 'overdue': overdue++; break;
      case 'pending': onTrack++; break;
      case 'partial': dueSoon++; break;
    }
  }

  final pctChange = revenueLastMonth == 0
      ? 0.0
      : ((revenueThisMonth - revenueLastMonth) / revenueLastMonth) * 100;

  return DashboardData(
    stats: DashboardStats(
      totalClients: totalClients,
      newClientsThisMonth: newClients,
      revenueThisMonth: revenueThisMonth,
      revenueChangePct: pctChange.toDouble(),
      overduePayments: overdueCount,
      newOverdueToday: newOverdueToday,
      activeProperties: activeProps,
      fullySoldProperties: soldOut,
    ),
    monthlyRevenue: monthlyRev,
    recentActivity: activity,
    paymentStatus: PaymentStatusBreakdown(
      onTrack: onTrack, dueSoon: dueSoon, overdue: overdue,
    ),
  );
});
