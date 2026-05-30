// lib/features/email/presentation/screens/email_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';
import 'package:go_router/go_router.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _myConfigProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).getMyAgencyConfig();
});

class EmailSettingsScreen extends ConsumerStatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  ConsumerState<EmailSettingsScreen> createState() =>
      _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends ConsumerState<EmailSettingsScreen> {
  final _fromNameCtrl = TextEditingController();
  final _replyToCtrl = TextEditingController();
  bool _saving = false;
  String? _error;
  bool _initialised = false;

  @override
  void dispose() {
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
      ),
      body: cfgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
                    const SizedBox(height: 20),
                    _domainCard(cfg),
                  ],
                ),
              ),
            ),
          );
        },
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
                'on them. Replies go to your Reply-to address. Later, you can verify '
                'your own domain to send from your real email.',
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

  Widget _domainCard(EmailProviderConfig? cfg) {
    final verified = cfg?.customDomainVerified ?? false;
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Verify your own domain',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text(
                      'Send emails from your real address (e.g. info@yourcompany.com) '
                          'for higher trust and deliverability.',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.muted, height: 1.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: verified
                      ? AppColors.brand.withOpacity(0.1)
                      : AppColors.warnLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  verified ? 'VERIFIED' : 'NOT VERIFIED',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: verified ? AppColors.brand : AppColors.warn,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Domain verification is coming soon. For now, emails send from Lintel\'s shared address.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ));
            },
            icon: const Icon(Icons.verified_outlined, size: 14),
            label: const Text('Set up domain (coming soon)'),
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