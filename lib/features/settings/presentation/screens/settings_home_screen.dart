// lib/features/settings/presentation/screens/settings_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions.dart';
import '../../../../core/theme/app_theme.dart';

/// Settings landing page reached from the account menu. Replaces the old
/// sidebar "Settings" section; tiles are gated by the same permissions the
/// nav used, so a marketer sees only what they're allowed to manage.
class SettingsHomeScreen extends ConsumerWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);

    final tiles = <Widget>[];
    if (perms.isAdmin) {
      tiles.add(_tile(
        context,
        Icons.credit_card_outlined,
        'Billing & plan',
        'Your subscription, usage, and payments',
        '/settings/billing',
      ));
    }
    if (perms.can(Permission.manageSignatures)) {
      tiles.add(_tile(
        context,
        Icons.draw_outlined,
        'Signatures',
        'Signing identities, directors, and the common seal',
        '/settings/signatures',
      ));
    }
    if (perms.can(Permission.manageContractTemplate)) {
      tiles.add(_tile(
        context,
        Icons.description_outlined,
        'Contract template',
        'The contract used for e-signing',
        '/settings/contract-template',
      ));
    }
    tiles.add(_tile(
      context,
      Icons.gavel,
      'Legal & policies',
      'Privacy, terms, and other policies',
      '/legal',
    ));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Manage your workspace configuration and policies.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            ...tiles,
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title,
      String subtitle, String route) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.brand),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: () => context.go(route),
      ),
    );
  }
}
