// lib/features/email/presentation/screens/custom_domain_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/email_repository.dart';
import '../../../billing/providers/billing_providers.dart';

final _emailRepoProvider = Provider((_) => EmailRepository());

final _configProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(_emailRepoProvider).getMyAgencyConfig();
});

class CustomDomainScreen extends ConsumerStatefulWidget {
  const CustomDomainScreen({super.key});

  @override
  ConsumerState<CustomDomainScreen> createState() => _CustomDomainScreenState();
}

class _CustomDomainScreenState extends ConsumerState<CustomDomainScreen> {
  final _domainCtrl = TextEditingController();
  final _prefixCtrl = TextEditingController(text: 'hello');
  bool _busy = false;
  String? _error;
  List<dynamic> _records = [];

  @override
  void dispose() {
    _domainCtrl.dispose();
    _prefixCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final domain = _domainCtrl.text.trim().toLowerCase();
    final prefix = _prefixCtrl.text.trim().toLowerCase();
    if (domain.isEmpty || !domain.contains('.')) {
      setState(() => _error = 'Enter a valid domain, e.g. sosoinvestment.com');
      return;
    }
    if (prefix.isEmpty || prefix.contains('@')) {
      setState(() => _error = 'Enter a sender prefix, e.g. hello');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final records = await ref
          .read(_emailRepoProvider)
          .createCustomDomain(domain: domain, prefix: prefix);
      setState(() => _records = records);
      ref.invalidate(_configProvider);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await ref.read(_emailRepoProvider).verifyCustomDomain();
      ref.invalidate(_configProvider);
      if (mounted) {
        final msg = status == 'verified'
            ? 'Domain verified! Your campaigns will now send from your domain.'
            : status == 'failed'
                ? 'Verification failed. Double-check the DNS records.'
                : 'Still pending — DNS can take up to a few hours to propagate.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionProvider);
    final cfgAsync = ref.watch(_configProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Custom sending domain')),
      body: subAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load plan: $e')),
        data: (sub) {
          final isPaid = sub?.isActive ?? false;
          if (!isPaid) return _upgradePrompt();

          return cfgAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load settings: $e')),
            data: (cfg) => _content(cfg),
          );
        },
      ),
    );
  }

  Widget _upgradePrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            const Text(
              'Custom sending domains are a paid feature',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upgrade your plan to send campaigns from your own domain '
              '(e.g. hello@youragency.com) instead of the shared Lintel address.',
              style: TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(EmailProviderConfig? cfg) {
    final status = cfg?.customDomainStatus ?? 'none';
    final records = _records.isNotEmpty
        ? _records
        : (cfg?.customDomainRecords ?? const []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (status != 'none') _statusBanner(status, cfg),
          const SizedBox(height: 16),

          if (status == 'none') ...[
            const Text(
              'Send from your own domain',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter your domain and the sender name you want. We\'ll give you '
              'DNS records to add at your domain provider.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: _field('Sender prefix', _prefixCtrl, 'hello'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 34, left: 6, right: 6),
                  child: Text('@', style: TextStyle(fontSize: 18)),
                ),
                Expanded(
                  child: _field('Your domain', _domainCtrl, 'youragency.com'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Emails will send from: '
              '${_prefixCtrl.text.trim().isEmpty ? "hello" : _prefixCtrl.text.trim()}'
              '@${_domainCtrl.text.trim().isEmpty ? "youragency.com" : _domainCtrl.text.trim()}',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.brand,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            _primaryButton('Add domain', _busy ? null : _create),
          ],

          if (records.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Add these DNS records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add each record at your domain provider (e.g. GoDaddy, '
              'Namecheap, Cloudflare). Then click Verify.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ...records.map((r) => _recordCard(r as Map<String, dynamic>)),
            const SizedBox(height: 16),
            Row(
              children: [
                _primaryButton(
                    status == 'verified' ? 'Verified ✓' : 'Verify domain',
                    (_busy || status == 'verified') ? null : _verify),
                const SizedBox(width: 12),
                if (_busy)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBanner(String status, EmailProviderConfig? cfg) {
    final (color, bg, label, icon) = switch (status) {
      'verified' => (
          AppColors.brand,
          AppColors.brandLight,
          'Verified — sending from ${cfg?.customFromPrefix}@${cfg?.customDomain}',
          Icons.check_circle,
        ),
      'failed' => (
          AppColors.danger,
          AppColors.dangerLight,
          'Verification failed — check your DNS records',
          Icons.error_outline,
        ),
      _ => (
          AppColors.gold,
          AppColors.goldLight,
          'Pending — add the DNS records below, then Verify',
          Icons.hourglass_empty,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> r) {
    final type = (r['type'] ?? r['record'] ?? '').toString();
    final name = (r['name'] ?? '').toString();
    final value = (r['value'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(type,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _copyRow('Name / Host', name),
          const SizedBox(height: 6),
          _copyRow('Value', value),
        ],
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ),
        Expanded(
          child: SelectableText(value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Copied'), duration: Duration(seconds: 1)),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy, size: 14, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController c, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: c,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: Text(label),
    );
  }
}
