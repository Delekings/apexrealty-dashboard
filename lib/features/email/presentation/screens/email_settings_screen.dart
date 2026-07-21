// lib/features/email/presentation/screens/email_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';
import '../widgets/email_engagement_row.dart';
import 'package:go_router/go_router.dart';
import 'package:lintel/core/widgets/lintel_loader.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _myConfigProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).getMyAgencyConfig();
});

/// Fetches the 50 most recent email_messages + their events for the agency.
final _recentActivityProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).recentAgencyEmailActivity(limit: 50);
});

class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _fromNameCtrl = TextEditingController();
  final _replyToCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _initialised = false;
  late final TabController _tabController =
  TabController(length: 2, vsync: this);
  String _activityFilter = 'all'; // all | campaign | signing_request | automation

  @override
  void dispose() {
    _tabController.dispose();
    _fromNameCtrl.dispose();
    _replyToCtrl.dispose();
    super.dispose();
  }

  void _populate(EmailProviderConfig? cfg) {
    if (_initialised) return;
    _fromNameCtrl.text = cfg?.fromName ?? '';
    _replyToCtrl.text = cfg?.replyToEmail ?? '';
    _initialised = true;
  }

  Future<void> _save() async {
    final replyTo = _replyToCtrl.text.trim();
    if (replyTo.isNotEmpty && !replyTo.contains('@')) {
      setState(() => _error = 'Reply-to must be a valid email address');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(_emailRepoProvider).saveMyAgencyConfig(
        fromName: _fromNameCtrl.text,
        replyToEmail: replyTo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Email settings saved'),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ));
      ref.invalidate(_myConfigProvider);
    } catch (e) {
      setState(() =>
      _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfgAsync = ref.watch(_myConfigProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => context.go('/'),
        ),
        title: const Text('Email settings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.brand,
          labelStyle:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Settings'),
            Tab(text: 'Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ----- Settings tab (the existing content) -----
          cfgAsync.when(
            loading: () => const Center(child: LintelLoader()),
            error: (e, _) => Center(
                child: Text('Failed: $e',
                    style: const TextStyle(color: AppColors.danger))),
            data: (cfg) {
              _populate(cfg);
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _infoCard(),
                        const SizedBox(height: 20),
                        _sendingCard(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // ----- Activity tab (new) -----
          _buildActivityTab(),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    final activityAsync = ref.watch(_recentActivityProvider);
    return Column(
      children: [
        // Filter chips row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('all', 'All'),
                const SizedBox(width: 8),
                _filterChip('campaign', 'Campaigns'),
                const SizedBox(width: 8),
                _filterChip('signing_request', 'Signing'),
                const SizedBox(width: 8),
                _filterChip('automation', 'Automations'),
              ],
            ),
          ),
        ),
        // List
        Expanded(
          child: activityAsync.when(
            loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load activity: $e',
                    style: const TextStyle(color: AppColors.muted)),
              ),
            ),
            data: (all) {
              final filtered = _activityFilter == 'all'
                  ? all
                  : all
                  .where((e) => e.message.emailType == _activityFilter)
                  .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _activityFilter == 'all'
                          ? 'No emails have been sent yet.'
                          : 'No ${_activityFilter.replaceAll("_", " ")} emails yet.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_recentActivityProvider);
                  await ref.read(_recentActivityProvider.future);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      EmailEngagementRow(engagement: filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = _activityFilter == value;
    return InkWell(
      onTap: () => setState(() => _activityFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How sending works',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            'Emails go out from Lintel\'s shared address with your agency\'s name '
                'on them. Replies go to your Reply-to address. On a paid plan you '
                'can verify your own domain below and send from your real email.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _sendingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sender identity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          const Text(
            'What your clients see in their inbox.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 16),

          _field(
            label: 'From name',
            controller: _fromNameCtrl,
            hint: 'e.g. Soso Investment',
            helper: 'The "From" name shown in clients\' inboxes.',
          ),
          _field(
            label: 'Reply-to email',
            controller: _replyToCtrl,
            hint: 'e.g. hello@sosoinvestment.com',
            helper:
            'When clients hit Reply, their message goes here. '
                'Leave blank to use your agency\'s primary email.',
          ),

          const SizedBox(height: 8),
          InkWell(
            onTap: () => context.push('/email/custom-domain'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brandLight.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.brand.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, color: AppColors.brand, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Custom sending domain',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        SizedBox(height: 2),
                        Text(
                          'Send from your own domain instead of the shared '
                          'Lintel address. (Paid plan)',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(_error!,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger)),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, size: 14),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
          if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(helper,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.muted)),
            )
          else
            const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint, isDense: true),
          ),
        ],
      ),
    );
  }
}
