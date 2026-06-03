// lib/features/dashboard/presentation/screens/dashboard_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/dashboard_providers.dart';
import '../widgets/stat_card.dart';
import '../widgets/activity_timeline.dart';
import '../../../../data/models/models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(dashboardProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.brand),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Failed to load: $e',
                style: const TextStyle(color: AppColors.danger)),
          ),
          data: (d) => _DashboardBody(data: d),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardData data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final crossAxisCount = isWide ? 4 : 2;
    final s = data.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Welcome back — ${DateFormat('EEEE, d MMMM yyyy').format(DateTime.now())}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Stat cards
        GridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 2.2 : 1.9,
          children: [
            StatCard(
              label: 'Total Clients',
              value: '${s.totalClients}',
              trend: '↑ ${s.newClientsThisMonth} this month',
              trendPositive: true,
            ),
            StatCard(
              label: 'Revenue',
              value: Formatters.nairaCompact(s.revenueThisMonth),
              trend: '${s.revenueChangePct >= 0 ? '↑' : '↓'} '
                  '${s.revenueChangePct.abs().toStringAsFixed(1)}% vs last month',
              trendPositive: s.revenueChangePct >= 0,
            ),
            StatCard(
              label: 'Overdue Payments',
              value: '${s.overduePayments}',
              trend: s.newOverdueToday > 0
                  ? '↑ ${s.newOverdueToday} new today'
                  : 'No new today',
              trendPositive: s.newOverdueToday == 0,
            ),
            StatCard(
              label: 'Active Properties',
              value: '${s.activeProperties}',
              trend: '${s.fullySoldProperties} fully sold',
              trendPositive: true,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Two-column row: revenue chart + activity timeline
        if (isWide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _RevenueChartCard(series: data.monthlyRevenue)),
                const SizedBox(width: 12),
                Expanded(child: _ActivityCard(entries: data.recentActivity)),
              ],
            ),
          )
        else ...[
          _RevenueChartCard(series: data.monthlyRevenue),
          const SizedBox(height: 12),
          _ActivityCard(entries: data.recentActivity),
        ],

        const SizedBox(height: 12),

        // Payment status card
        _PaymentStatusCard(breakdown: data.paymentStatus),
      ],
    );
  }
}

class _RevenueChartCard extends StatelessWidget {
  final List<MonthlyRevenue> series;
  const _RevenueChartCard({required this.series});

  @override
  Widget build(BuildContext context) {
    final maxVal = series.isEmpty
        ? 1.0
        : series.map((s) => s.amount.toDouble()).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Revenue',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: series.isEmpty
                  ? const Center(
                      child: Text('No revenue data yet',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxVal * 1.1,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AppColors.text,
                            getTooltipItem: (group, _, rod, __) {
                              return BarTooltipItem(
                                Formatters.nairaCompact(rod.toY),
                                const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (val, _) {
                                final i = val.toInt();
                                if (i < 0 || i >= series.length) {
                                  return const SizedBox();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(series[i].label,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted)),
                                );
                              },
                            ),
                          ),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          for (var i = 0; i < series.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: series[i].amount.toDouble(),
                                  color: i == series.length - 1
                                      ? AppColors.brand
                                      : AppColors.brand.withOpacity(0.35),
                                  width: 22,
                                  borderRadius:
                                      const BorderRadius.all(Radius.circular(4)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final List<ActivityEntry> entries;
  const _ActivityCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recent Activity',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No activity yet',
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              )
            else
              ActivityTimeline(entries: entries),
          ],
        ),
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  final PaymentStatusBreakdown breakdown;
  const _PaymentStatusCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.onTrack + breakdown.dueSoon + breakdown.overdue;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Status',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 4),
            Text('$total active installments',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 14),
            _StatusBar(breakdown: breakdown),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatusLegend(
                    color: AppColors.brand,
                    label: 'On track',
                    count: breakdown.onTrack),
                const SizedBox(width: 16),
                _StatusLegend(
                    color: AppColors.gold,
                    label: 'Due soon',
                    count: breakdown.dueSoon),
                const SizedBox(width: 16),
                _StatusLegend(
                    color: AppColors.danger,
                    label: 'Overdue',
                    count: breakdown.overdue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final PaymentStatusBreakdown breakdown;
  const _StatusBar({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = (breakdown.onTrack + breakdown.dueSoon + breakdown.overdue)
        .clamp(1, 1 << 30);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(flex: breakdown.onTrack, child: Container(color: AppColors.brand)),
            Expanded(flex: breakdown.dueSoon, child: Container(color: AppColors.gold)),
            Expanded(flex: breakdown.overdue, child: Container(color: AppColors.danger)),
            // Filler so the bar always renders even when all values are 0
            if (total == 1) Expanded(flex: 1, child: Container(color: AppColors.bg2)),
          ],
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  const _StatusLegend({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label · $count',
            style: const TextStyle(fontSize: 12, color: AppColors.text)),
      ],
    );
  }
}
