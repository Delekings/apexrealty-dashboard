// lib/features/email/presentation/screens/email_campaigns_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';
import '../widgets/new_campaign_dialog.dart';
import 'package:go_router/go_router.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _campaignsProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).listCampaigns();
});

class EmailCampaignsScreen extends ConsumerWidget {
  const EmailCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_campaignsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Email campaigns'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(_campaignsProvider),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New campaign'),
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const NewCampaignDialog(),
              );
              ref.invalidate(_campaignsProvider);
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Failed: $e',
                style: const TextStyle(color: AppColors.danger))),
        data: (campaigns) {
          if (campaigns.isEmpty) {
            return _emptyState();
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statsRow(campaigns),
                    const SizedBox(height: 20),
                    _table(campaigns),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.mail_outline,
                    size: 28, color: AppColors.brand),
              ),
              const SizedBox(height: 16),
              const Text('No campaigns yet',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Every email you send shows up here. Start by sending a single email '
                    'from a client\'s profile, or wait for the bulk-send feature (coming soon).',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.muted, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow(List<EmailCampaign> campaigns) {
    final totalSent = campaigns.fold<int>(0, (s, c) => s + c.sentCount);
    final totalCampaigns = campaigns.length;
    final scheduled =
        campaigns.where((c) => c.status == 'scheduled').length;

    return Row(
      children: [
        Expanded(child: _statCard('Total campaigns', totalCampaigns.toString())),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Emails sent', totalSent.toString())),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Scheduled', scheduled.toString())),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.muted,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _table(List<EmailCampaign> campaigns) {
    final df = DateFormat('d MMM, HH:mm');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.bg2,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('Subject',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted))),
                Expanded(
                    flex: 2,
                    child: Text('Status',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted))),
                Expanded(
                    flex: 2,
                    child: Text('Recipients',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted))),
                Expanded(
                    flex: 3,
                    child: Text('Sent',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.muted))),
              ],
            ),
          ),
          for (final c in campaigns)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Expanded(flex: 2, child: _statusBadge(c.status)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${c.sentCount}/${c.totalRecipients}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      c.sendCompletedAt != null
                          ? df.format(c.sendCompletedAt!.toLocal())
                          : c.scheduledFor != null
                          ? 'Scheduled ${df.format(c.scheduledFor!.toLocal())}'
                          : df.format(c.createdAt.toLocal()),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final (color, bg, label) = switch (status) {
      'draft' => (AppColors.muted, AppColors.bg2, 'Draft'),
      'scheduled' => (AppColors.warn, AppColors.warnLight, 'Scheduled'),
      'sending' => (AppColors.brand, AppColors.brandLight, 'Sending'),
      'sent' => (AppColors.brand, AppColors.brandLight, 'Sent'),
      'partially_failed' => (
      AppColors.warn,
      AppColors.warnLight,
      'Partial'
      ),
      'failed' => (AppColors.danger, AppColors.dangerLight, 'Failed'),
      'cancelled' => (AppColors.muted, AppColors.bg2, 'Cancelled'),
      _ => (AppColors.muted, AppColors.bg2, status),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6),
        ),
      ),
    );
  }
}