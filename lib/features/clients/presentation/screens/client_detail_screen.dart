// lib/features/clients/presentation/screens/client_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../data/repositories/clients_repository.dart';
import '../../../dashboard/presentation/widgets/activity_timeline.dart';
import '../widgets/send_email_dialog.dart';
import '../../providers/clients_providers.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientDetailProvider(clientId));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: async.when(
        loading: () => const Center(
            child: LintelLoader()),
        error: (e, _) => Center(
          child: Text('Couldn\'t load client: $e',
              style: const TextStyle(color: AppColors.danger)),
        ),
        data: (d) => _Body(detail: d),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final ClientDetail detail;
  const _Body({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = detail.client;
    final wide = MediaQuery.of(context).size.width >= 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top header
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => context.go('/clients'),
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.brandLight,
              child: Text(
                _initials(c.fullName),
                style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.fullName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${c.phone}${c.email != null ? ' · ${c.email}' : ''}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _launchCall(c.phone),
              icon: const Icon(Icons.phone_outlined, size: 16),
              label: const Text('Call'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _launchWhatsApp(c.phone),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('WhatsApp'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: c.email == null || c.email!.isEmpty
                  ? null
                  : () => showDialog(
                context: context,
                builder: (_) => SendEmailDialog(detail: detail),
              ),
              icon: const Icon(Icons.mail_outline, size: 16),
              label: const Text('Email'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                // Future: navigate to new contract form pre-filling client
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New contract — coming next')),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New contract'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Body
        Expanded(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 320, child: _OverviewCard(detail: detail)),
                    const SizedBox(width: 16),
                    Expanded(child: _MainColumn(detail: detail)),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _OverviewCard(detail: detail),
                      const SizedBox(height: 12),
                      _MainColumn(detail: detail),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Future<void> _launchCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Normalize to international format: assume Nigerian if local
    var p = phone.replaceAll(RegExp(r'\s|-'), '');
    if (p.startsWith('0')) p = '234${p.substring(1)}';
    p = p.replaceAll('+', '');
    final uri = Uri.parse('https://wa.me/$p');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _OverviewCard extends StatelessWidget {
  final ClientDetail detail;
  const _OverviewCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = detail.client;
    final totalContractValue =
        detail.contracts.fold<num>(0, (s, c) => s + c.totalPrice);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Overview'),
            const SizedBox(height: 12),
            _kv('Phone', c.phone),
            _kv('Email', c.email ?? '—'),
            _kv('State', c.state ?? '—'),
            _kv('Onboarded', Formatters.date(c.createdAt)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total contract value',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.brand)),
                  const SizedBox(height: 2),
                  Text(
                    Formatters.naira(totalContractValue),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(k,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted)),
            ),
            Expanded(
              child: Text(v,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.text)),
            ),
          ],
        ),
      );
}

class _MainColumn extends StatelessWidget {
  final ClientDetail detail;
  const _MainColumn({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContractsCard(contracts: detail.contracts),
        const SizedBox(height: 12),
        _PaymentsCard(payments: detail.recentPayments),
        const SizedBox(height: 12),
        _ActivityCard(entries: detail.activity),
      ],
    );
  }
}

class _ContractsCard extends StatelessWidget {
  final List<ContractSummary> contracts;
  const _ContractsCard({required this.contracts});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Contracts'),
            const SizedBox(height: 12),
            if (contracts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No contracts yet',
                  message:
                      'When this client buys a property, the contract will appear here.',
                ),
              )
            else
              for (final c in contracts) _contractRow(c),
          ],
        ),
      ),
    );
  }

  Widget _contractRow(ContractSummary c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.home_work_outlined, color: AppColors.brand, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.propertyTitle ?? '—',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                  '${c.contractNo} · ${c.propertyLocation ?? ''}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.naira(c.totalPrice),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text(c.status,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  final List<PaymentSummary> payments;
  const _PaymentsCard({required this.payments});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Recent payments'),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('No payments recorded yet',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
              )
            else
              for (final p in payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.brand, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${Formatters.naira(p.amount)} · ${p.channel}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        Formatters.relative(p.paidAt),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final List entries;
  const _ActivityCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Activity'),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('No activity logged yet',
                  style: TextStyle(fontSize: 13, color: AppColors.muted))
            else
              ActivityTimeline(entries: entries.cast()),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) => Text(
        label,
        style:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );
}
