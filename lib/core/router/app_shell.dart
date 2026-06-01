// lib/core/router/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import 'app_router.dart' show captureRouterContext;
import '../theme/app_theme.dart';

class _NavEntry {
  final String label;
  final IconData icon;
  final String route;
  final int? badge;
  final String? section;
  const _NavEntry(this.label, this.icon, this.route, {this.badge, this.section});
}

const _nav = <_NavEntry>[
  _NavEntry('Dashboard', Icons.dashboard_outlined, '/', section: 'Overview'),
  _NavEntry('Alerts', Icons.notifications_none_rounded, '/reminders', badge: 5, section: 'Overview'),

  _NavEntry('All Clients', Icons.people_outline, '/clients', section: 'Clients'),
  _NavEntry('Contracts', Icons.assignment_outlined, '/contracts', section: 'Clients'),
  _NavEntry('Installments', Icons.payments_outlined, '/installments', badge: 3, section: 'Clients'),

  _NavEntry('Campaigns', Icons.send_outlined, '/email/campaigns', section: 'Email'),
  _NavEntry('Automations', Icons.auto_awesome_outlined, '/email/automations', section: 'Email'),
  _NavEntry('Email settings', Icons.tune_outlined, '/email/settings', section: 'Email'),

  _NavEntry('Signed contracts', Icons.assignment_turned_in_outlined, '/documents', section: 'Documents'),
  _NavEntry('Signatures', Icons.draw_outlined, '/settings/signatures', section: 'Settings'),
  _NavEntry('Contract template', Icons.description_outlined, '/settings/contract-template', section: 'Settings'),
  _NavEntry('Staff', Icons.badge_outlined, '/staff', section: 'Staff'),

  _NavEntry('Properties', Icons.home_work_outlined, '/properties', section: 'Properties'),
];

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Capture this context so we can navigate from outside the widget
    // tree (e.g. when Supabase fires a PASSWORD_RECOVERY event).
    captureRouterContext(context);

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;

    return Scaffold(
      appBar: _TopBar(profile: profile, showMenuButton: !isWide),
      drawer: isWide ? null : Drawer(child: _Sidebar()),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isWide)
            const SizedBox(
              width: 220,
              child: _Sidebar(),
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final dynamic profile;
  final bool showMenuButton;
  const _TopBar({required this.profile, required this.showMenuButton});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      automaticallyImplyLeading: showMenuButton,
      title: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('Lin',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const Text('tel',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.brand)),
        ],
      ),
      actions: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('🇳🇬 Nigeria',
              style: TextStyle(color: AppColors.brand, fontSize: 11, fontWeight: FontWeight.w500)),
        ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go('/reminders'),
            ),
            Positioned(
              top: 10, right: 10,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 40),
          onSelected: (v) async {
            if (v == 'signout') {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/signin');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'signout', child: Text('Sign out')),
          ],
          child: CircleAvatar(
            radius: 15,
            backgroundColor: AppColors.brand,
            child: Text(
              profile?.initials ?? 'AD',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;

    final grouped = <String, List<_NavEntry>>{};
    for (final n in _nav) {
      grouped.putIfAbsent(n.section ?? 'Other', () => []).add(n);
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        color: AppColors.bg,
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Text(
                entry.key.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (final item in entry.value)
              _NavTile(item: item, isActive: currentPath == item.route),
          ],
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavEntry item;
  final bool isActive;
  const _NavTile({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go(item.route),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.brandLight : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                size: 18,
                color: isActive ? AppColors.brand : AppColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? AppColors.brand : AppColors.text,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
              if (item.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.badge}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}