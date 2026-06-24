// lib/features/finances/presentation/screens/finance_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/layout_helpers.dart';
import '../../../../data/repositories/finance_report_repository.dart';
import '../../providers/finance_report_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class FinanceReportScreen extends ConsumerWidget {
  const FinanceReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(financePeriodProvider);
    final async = ref.watch(financeSummaryProvider);

    final chips = Wrap(
      spacing: 6,
      children: [
        for (final p in FinancePeriod.values)
          ChoiceChip(
            label: Text(p.label, style: const TextStyle(fontSize: 12)),
            selected: period == p,
            onSelected: (_) =>
                ref.read(financePeriodProvider.notifier).state = p,
            selectedColor: AppColors.brandLight,
            visualDensity: VisualDensity.compact,
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.isMobile) ...[
            const _Title(),
            const SizedBox(height: 12),
            chips,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: _Title()),
                chips,
              ],
            ),
          const SizedBox(height: 16),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: LintelLoader()),
              error: (e, _) => Center(
                child: Text('Failed to load report: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (s) => SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ResponsiveGrid(
                      spacing: 12,
                      runSpacing: 12,
                      mobileColumns: 1,
                      tabletColumns: 3,
                      desktopColumns: 3,
                      children: [
                        _StatCard(
                          label: 'Total income',
                          value: s.totalIncome,
                          accent: AppColors.brand,
                          icon: Icons.trending_up,
                        ),
                        _StatCard(
                          label: 'Total expenses',
                          value: s.expensesTotal,
                          accent: AppColors.warn,
                          icon: Icons.trending_down,
                        ),
                        _StatCard(
                          label: 'Net profit',
                          value: s.net,
                          accent: s.net >= 0 ? AppColors.brand : AppColors.danger,
                          icon: s.net >= 0
                              ? Icons.account_balance_wallet_outlined
                              : Icons.warning_amber_rounded,
                          emphasise: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (s.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No income or expenses recorded in this period.',
                            style:
                                TextStyle(fontSize: 13, color: AppColors.muted),
                          ),
                        ),
                      )
                    else ...[
                      _BreakdownCard(
                        title: 'Income',
                        total: s.totalIncome,
                        rows: [
                          if (s.saleIncome > 0)
                            _Row('Sale payments', s.saleIncome),
                          ...(s.otherIncomeBySource.entries.toList()
                                ..sort((a, b) => b.value.compareTo(a.value)))
                              .map((e) => _Row(e.key, e.value)),
                        ],
                        barColor: AppColors.brand,
                      ),
                      const SizedBox(height: 14),
                      _BreakdownCard(
                        title: 'Expenses',
                        total: s.expensesTotal,
                        rows: (s.expensesByCategory.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value)))
                            .map((e) => _Row(e.key, e.value))
                            .toList(),
                        barColor: AppColors.warn,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profit & Loss',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text('Income from sales and other sources, minus expenses.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final num value;
  final Color accent;
  final IconData icon;
  final bool emphasise;

  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasise ? accent.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: emphasise ? accent.withOpacity(0.4) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Formatters.naira(value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: emphasise ? accent : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final num amount;
  const _Row(this.label, this.amount);
}

class _BreakdownCard extends StatelessWidget {
  final String title;
  final num total;
  final List<_Row> rows;
  final Color barColor;

  const _BreakdownCard({
    required this.title,
    required this.total,
    required this.rows,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              Text(Formatters.naira(total),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
            ],
          ),
          if (rows.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('Nothing recorded.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ] else
            for (final r in rows) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(r.label,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(Formatters.naira(r.amount),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 5),
              _bar(total <= 0 ? 0 : (r.amount / total).toDouble()),
            ],
        ],
      ),
    );
  }

  Widget _bar(double frac) {
    return SizedBox(
      height: 6,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          FractionallySizedBox(
            widthFactor: frac.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
