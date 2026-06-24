// lib/features/billing/presentation/screens/billing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/billing_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

const _featureLabels = <String, String>{
  'email_automations': 'Email automations',
  'csv_import': 'CSV import',
  'branding': 'Custom branding',
  'booking_page': 'Public booking page',
  'commissions': 'Commissions',
  'advanced_reporting': 'Advanced reporting',
  'api': 'API access',
  'custom_domain': 'Custom domain',
  'multi_agency': 'Multi-agency',
};

String _naira(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '\u20A6$b';
}

String _date(DateTime? d) {
  if (d == null) return '\u2014';
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionProvider);
    final plansAsync = ref.watch(plansProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Billing & plan',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Manage your subscription, usage, and payments.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 18),

            subAsync.when(
              loading: () => const _LoadingBox(),
              error: (e, _) => _ErrorBox('Could not load your subscription.'),
              data: (sub) => _CurrentPlanCard(sub: sub),
            ),
            const SizedBox(height: 16),

            subAsync.maybeWhen(
              data: (sub) => _UsageCard(sub: sub),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),

            const Text('Plans',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            plansAsync.when(
              loading: () => const _LoadingBox(),
              error: (e, _) => _ErrorBox('Could not load plans.'),
              data: (plans) {
                final currentCode = subAsync.asData?.value?.planCode;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final p in plans)
                      _PlanCard(
                        plan: p,
                        isCurrent: p.code == currentCode,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            const Text('Payment history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            const _HistoryList(),
          ],
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final AgencySubscription? sub;
  const _CurrentPlanCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final planName = sub?.plan?.name ?? 'Free';
    final price = sub?.plan?.priceNaira ?? 0;

    String statusLabel;
    Color statusColor;
    String detail;
    switch (sub?.status) {
      case 'trialing':
        statusLabel = 'Trial';
        statusColor = AppColors.info;
        final d = sub?.trialDaysLeft ?? 0;
        detail = '$d ${d == 1 ? "day" : "days"} left \u00B7 ends ${_date(sub?.trialEndsAt)}';
        break;
      case 'past_due':
        statusLabel = 'Payment due';
        statusColor = AppColors.danger;
        detail = 'Your last payment failed. Update billing to keep $planName.';
        break;
      case 'canceled':
        statusLabel = 'Canceling';
        statusColor = AppColors.warn;
        detail = 'Access until ${_date(sub?.currentPeriodEnd)}, then Free.';
        break;
      default:
        statusLabel = 'Active';
        statusColor = AppColors.brand;
        detail = price > 0
            ? 'Renews ${_date(sub?.currentPeriodEnd)}'
            : 'No payment needed on the Free plan.';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(planName,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
              const Spacer(),
              if (price > 0)
                Text('${_naira(price)} / mo',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _UsageCard extends ConsumerWidget {
  final AgencySubscription? sub;
  const _UsageCard({required this.sub});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = sub?.plan;
    final usageAsync = ref.watch(usageProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: usageAsync.when(
        loading: () => const SizedBox(
            height: 40, child: Center(child: LintelLoader())),
        error: (e, _) => const Text('Could not load usage.',
            style: TextStyle(color: AppColors.muted)),
        data: (u) => Column(
          children: [
            _usageRow('Team members', u.users, plan?.maxUsers),
            const SizedBox(height: 12),
            _usageRow('Clients', u.clients, plan?.maxClients),
            const SizedBox(height: 12),
            _usageRow('Properties', u.properties, plan?.maxProperties),
          ],
        ),
      ),
    );
  }

  Widget _usageRow(String label, int used, int? limit) {
    final unlimited = limit == null;
    final pct = unlimited ? 0.0 : (limit == 0 ? 1.0 : (used / limit).clamp(0.0, 1.0));
    final over = !unlimited && used >= limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              unlimited ? '$used \u00B7 Unlimited' : '$used / $limit',
              style: TextStyle(
                  fontSize: 13,
                  color: over ? AppColors.danger : AppColors.muted,
                  fontWeight: over ? FontWeight.w600 : FontWeight.w400),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: unlimited ? 0.04 : pct,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
                over ? AppColors.danger : AppColors.brand),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  final BillingPlan plan;
  final bool isCurrent;
  const _PlanCard({required this.plan, required this.isCurrent});

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _busy = false;

  Future<void> _subscribe() async {
    setState(() => _busy = true);
    try {
      final link =
          await ref.read(billingRepositoryProvider).checkout(widget.plan.code);
      if (!mounted) return;
      await launchUrl(Uri.parse(link), webOnlyWindowName: '_self');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.plan;
    final limits = <String>[
      p.maxUsers == null ? 'Unlimited users' : '${p.maxUsers} users',
      p.maxClients == null ? 'Unlimited clients' : '${p.maxClients} clients',
      p.maxProperties == null
          ? 'Unlimited properties'
          : '${p.maxProperties} properties',
    ];

    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isCurrent ? AppColors.brand : AppColors.border,
          width: widget.isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(p.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (widget.isCurrent)
                const Icon(Icons.check_circle,
                    color: AppColors.brand, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(p.isFree ? '\u20A60' : _naira(p.priceNaira),
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
              const Text('/ mo',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          for (final l in limits) _line(l, strong: true),
          for (final f in p.features)
            _line(_featureLabels[f] ?? f, strong: false),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _button(),
          ),
        ],
      ),
    );
  }

  Widget _button() {
    if (widget.isCurrent) {
      return OutlinedButton(
        onPressed: null,
        child: const Text('Current plan'),
      );
    }
    if (widget.plan.isFree) {
      // Free is the fallback tier; you reach it by lapsing/canceling, not buying.
      return const SizedBox.shrink();
    }
    return FilledButton(
      onPressed: _busy ? null : _subscribe,
      child: _busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Text('Choose plan'),
    );
  }

  Widget _line(String text, {required bool strong}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check,
              size: 15,
              color: strong ? AppColors.brand : AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: strong ? FontWeight.w600 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends ConsumerWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(billingHistoryProvider);
    return histAsync.when(
      loading: () => const _LoadingBox(),
      error: (e, _) => _ErrorBox('Could not load payment history.'),
      data: (txns) {
        if (txns.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text('No payments yet.',
                style: TextStyle(color: AppColors.muted)),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < txns.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _row(txns[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(BillingTxn t) {
    Color c;
    switch (t.status) {
      case 'successful':
        c = AppColors.brand;
        break;
      case 'failed':
        c = AppColors.danger;
        break;
      default:
        c = AppColors.muted;
    }
    return ListTile(
      dense: true,
      title: Text(
        '${(t.planCode ?? "").isEmpty ? "Payment" : t.planCode![0].toUpperCase() + t.planCode!.substring(1)} \u00B7 ${_naira(t.amountNaira)}',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_date(t.paidAt ?? t.createdAt),
          style: const TextStyle(fontSize: 12)),
      trailing: Text(t.status,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();
  @override
  Widget build(BuildContext context) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: LintelLoader()),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        ),
        child: Text(message, style: const TextStyle(color: AppColors.danger)),
      );
}
