// lib/features/email/presentation/screens/email_automations_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';
import '../widgets/automation_editor_dialog.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _automationsProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).listAutomations();
});

class EmailAutomationsScreen extends ConsumerStatefulWidget {
  const EmailAutomationsScreen({super.key});

  @override
  ConsumerState<EmailAutomationsScreen> createState() =>
      _EmailAutomationsScreenState();
}

class _EmailAutomationsScreenState
    extends ConsumerState<EmailAutomationsScreen> {
  bool _runningNow = false;

  Future<void> _runNow() async {
    setState(() => _runningNow = true);
    try {
      final result =
      await ref.read(_emailRepoProvider).runAutomationsNow();
      if (!mounted) return;
      final count = result['automationsProcessed'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ran $count automation${count == 1 ? "" : "s"}'),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
      ));
      ref.invalidate(_automationsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed: $e'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _runningNow = false);
    }
  }

  Future<void> _openCreateDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const AutomationEditorDialog(),
    );
    ref.invalidate(_automationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_automationsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Email automations'),
        actions: [
          OutlinedButton.icon(
            icon: _runningNow
                ? const SizedBox(
                width: 14,
                height: 14,
                child:
                CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow, size: 16),
            label: Text(_runningNow ? 'Running…' : 'Run now'),
            onPressed: _runningNow ? null : _runNow,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New rule'),
            onPressed: _openCreateDialog,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Failed: $e',
                style: const TextStyle(color: AppColors.danger))),
        data: (automations) {
          if (automations.isEmpty) return _emptyState();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoCard(),
                    const SizedBox(height: 20),
                    for (final a in automations) _automationCard(a),
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
        constraints: const BoxConstraints(maxWidth: 480),
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
                child: const Icon(Icons.auto_awesome_outlined,
                    size: 28, color: AppColors.brand),
              ),
              const SizedBox(height: 16),
              const Text('No automations yet',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'Automations let Lintel send the right email at the right time '
                    'without you lifting a finger. Birthday greetings, payment '
                    'reminders, contract anniversaries — Lintel handles them all.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.muted, height: 1.6),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Create your first rule'),
                onPressed: _openCreateDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.muted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Automations run once a day. Use "Run now" to test a rule '
                  'immediately after creating it.',
              style: TextStyle(
                  fontSize: 12, color: AppColors.muted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _automationCard(EmailAutomation a) {
    final df = DateFormat('d MMM yyyy, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: a.isActive ? AppColors.brand.withOpacity(0.3) : AppColors.border,
            width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(a.describeTrigger(),
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Switch(
                value: a.isActive,
                onChanged: (v) async {
                  await ref.read(_emailRepoProvider).setAutomationActive(
                      automationId: a.id, isActive: v);
                  ref.invalidate(_automationsProvider);
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) async {
                  if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Delete "${a.name}"?'),
                        content: const Text(
                          'This rule will stop running. Already-sent emails are kept.',
                          style: TextStyle(fontSize: 13),
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(_emailRepoProvider).deleteAutomation(a.id);
                      ref.invalidate(_automationsProvider);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'delete',
                      child:
                      Text('Delete', style: TextStyle(fontSize: 13))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subject: ${a.subjectTemplate}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(
                  a.bodyHtmlTemplate
                      .replaceAll(RegExp(r'<[^>]+>'), ' ')
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (a.lastRunAt != null) ...[
                const Icon(Icons.history,
                    size: 12, color: AppColors.muted),
                const SizedBox(width: 4),
                Text('Last ran ${df.format(a.lastRunAt!.toLocal())}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.muted)),
                const SizedBox(width: 12),
              ],
              const Icon(Icons.mail_outline,
                  size: 12, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                  '${a.totalSentCount} email${a.totalSentCount == 1 ? "" : "s"} sent',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }
}