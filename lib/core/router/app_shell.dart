// lib/core/router/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../auth/permissions.dart';
import '../responsive/breakpoints.dart';
import 'app_router.dart' show captureRouterContext;
import '../theme/app_theme.dart';
import '../../features/settings/presentation/widgets/account_deletion_dialog.dart';

class _NavEntry {
  final String label;
  final IconData icon;
  final String route;
  final int? badge;
  final String? section;

  /// If non-null, the user must have this permission for the entry to render.
  final Permission? requiredPermission;

  /// If true, the entry is hidden from external agents (marketers).
  final bool hideFromMarketers;

  /// If true, the entry is hidden entirely — used for screens still being built.
  final bool comingSoon;
  const _NavEntry(
      this.label,
      this.icon,
      this.route, {
        this.badge,
        this.section,
        this.requiredPermission,
        this.hideFromMarketers = false,
        this.comingSoon = false,
      });
}

const _nav = <_NavEntry>[
  _NavEntry('Dashboard', Icons.dashboard_outlined, '/', section: 'Overview'),
  _NavEntry('Alerts', Icons.notifications_none_rounded, '/reminders',
      badge: 5, section: 'Overview', comingSoon: true),

  _NavEntry('All Clients', Icons.people_outline, '/clients',
      section: 'Clients', hideFromMarketers: true),
  _NavEntry('Contracts', Icons.assignment_outlined, '/contracts',
      section: 'Clients', hideFromMarketers: true),
  _NavEntry('Installments', Icons.payments_outlined, '/installments',
      badge: 3, section: 'Clients', hideFromMarketers: true, comingSoon: true),
  _NavEntry('Import clients', Icons.upload_file_outlined, '/clients/import',
      section: 'Clients',
      requiredPermission: Permission.editAnyClient),

  _NavEntry('Expenses', Icons.receipt_long_outlined, '/expenses',
      section: 'Finances', hideFromMarketers: true),
  _NavEntry('Other income', Icons.savings_outlined, '/income',
      section: 'Finances', hideFromMarketers: true),
  _NavEntry('Profit & Loss', Icons.insights_outlined, '/pnl',
      section: 'Finances', hideFromMarketers: true),
  _NavEntry('Recurring', Icons.event_repeat_outlined, '/recurring',
      section: 'Finances', hideFromMarketers: true),

  _NavEntry('Campaigns', Icons.send_outlined, '/email/campaigns',
      section: 'Email',
      requiredPermission: Permission.manageEmailSettings),
  _NavEntry('Email builder', Icons.dashboard_customize_outlined, '/email/builder',
      section: 'Email',
      requiredPermission: Permission.manageEmailSettings),
  _NavEntry('Automations', Icons.auto_awesome_outlined, '/email/automations',
      section: 'Email',
      requiredPermission: Permission.manageEmailSettings),
  _NavEntry('Email settings', Icons.tune_outlined, '/email/settings',
      section: 'Email',
      requiredPermission: Permission.manageEmailSettings),

  _NavEntry('Signed contracts', Icons.assignment_turned_in_outlined, '/documents',
      section: 'Documents', hideFromMarketers: true, comingSoon: true),

  _NavEntry('Bookings', Icons.event_outlined, '/bookings',
      section: 'Shortlet / Hotel', hideFromMarketers: true),

  _NavEntry('Staff', Icons.badge_outlined, '/staff',
      section: 'Staff',
      requiredPermission: Permission.manageStaff),

  _NavEntry('Properties', Icons.home_work_outlined, '/properties',
      section: 'Properties',
      requiredPermission: Permission.manageProperties),
];

/// Bottom-nav primary destinations for mobile, in priority order. Each is
/// shown only if the matching [_nav] entry is visible to the user; the first
/// three that survive filtering are used, then a "More" button that opens the
/// full drawer. Short labels (vs the sidebar's longer ones) suit a phone bar.
const _bottomCandidates = <({String route, IconData icon, String label})>[
  (route: '/', icon: Icons.dashboard_outlined, label: 'Home'),
  (route: '/clients', icon: Icons.people_outline, label: 'Clients'),
  (route: '/bookings', icon: Icons.event_outlined, label: 'Bookings'),
  (route: '/contracts', icon: Icons.assignment_outlined, label: 'Contracts'),
  (route: '/properties', icon: Icons.home_work_outlined, label: 'Properties'),
];

/// Shared visibility predicate used by sidebar, rail and bottom nav so all
/// three honour the same permission / marketer / coming-soon rules.
List<_NavEntry> _visibleEntries(PermissionSet perms) {
  return _nav.where((n) {
    if (n.comingSoon) return false;
    if (n.hideFromMarketers && perms.isMarketer) return false;
    if (n.requiredPermission != null && !perms.can(n.requiredPermission!)) {
      return false;
    }
    return true;
  }).toList();
}

/// Active-state matcher. Exact for '/', prefix-aware for everything else so
/// detail routes (e.g. /clients/123) keep their parent tab highlighted.
bool _isActive(String currentPath, String route) {
  if (route == '/') return currentPath == '/';
  return currentPath == route || currentPath.startsWith('$route/');
}

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  // Held in State so it survives child-route changes (ShellRoute keeps the
  // shell mounted) and lets the bottom-nav "More" button open the drawer.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    // Capture this context so we can navigate from outside the widget
    // tree (e.g. when Supabase fires a PASSWORD_RECOVERY event).
    captureRouterContext(context);

    final profile = ref.watch(currentProfileProvider).value;

    switch (context.breakpoint) {
    // ---------- DESKTOP: full labelled sidebar ----------
      case Breakpoint.desktop:
        return Scaffold(
          key: _scaffoldKey,
          appBar: _TopBar(profile: profile, showMenuButton: false),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 220, child: _Sidebar()),
              Expanded(child: widget.child),
            ],
          ),
        );

    // ---------- TABLET: compact icon rail (all entries) ----------
      case Breakpoint.tablet:
        return Scaffold(
          key: _scaffoldKey,
          appBar: _TopBar(profile: profile, showMenuButton: false),
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _NavRail(),
              Expanded(child: widget.child),
            ],
          ),
        );

    // ---------- MOBILE: bottom nav + drawer for overflow ----------
      case Breakpoint.mobile:
        return Scaffold(
          key: _scaffoldKey,
          appBar: _TopBar(profile: profile, showMenuButton: true),
          drawer: const Drawer(child: _Sidebar()),
          body: widget.child,
          bottomNavigationBar: _BottomNav(
            onMore: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        );
    }
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
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Account',
          offset: const Offset(0, 40),
          onSelected: (v) async {
            if (v == 'settings') {
              context.go('/settings');
            } else if (v == 'legal') {
              context.go('/legal');
            } else if (v == 'delete') {
              await showDialog(
                context: context,
                builder: (_) => AccountDeletionDialog(
                  agencyId: profile?.agencyId,
                  email: profile?.email,
                ),
              );
            } else if (v == 'signout') {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/signin');
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'settings', child: Text('Settings')),
            PopupMenuItem(value: 'legal', child: Text('Legal & policies')),
            PopupMenuItem(value: 'delete', child: Text('Delete account')),
            PopupMenuDivider(),
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

/// Full labelled sidebar (desktop) and drawer contents (mobile).
class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final perms = ref.watch(permissionsProvider);

    final visible = _visibleEntries(perms);

    // Group by section, preserving original order.
    final grouped = <String, List<_NavEntry>>{};
    for (final n in visible) {
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
              _NavTile(item: item, isActive: _isActive(currentPath, item.route)),
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
              if (item.badge != null) _NavBadge(count: item.badge!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tablet: a 64px icon rail showing every visible entry (scrollable), with
/// tooltips for labels. Mirrors the desktop sidebar's order so muscle memory
/// carries over while saving horizontal space for content.
class _NavRail extends ConsumerWidget {
  const _NavRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final perms = ref.watch(permissionsProvider);
    final visible = _visibleEntries(perms);

    return Container(
      width: 64,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border, width: 0.5)),
        color: AppColors.bg,
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          for (final item in visible)
            _RailTile(item: item, isActive: _isActive(currentPath, item.route)),
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  final _NavEntry item;
  final bool isActive;
  const _RailTile({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(item.route),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: isActive ? AppColors.brandLight : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: isActive ? AppColors.brand : AppColors.muted,
                ),
                if (item.badge != null)
                  Positioned(
                    right: 8,
                    top: 5,
                    child: _NavBadge(count: item.badge!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile: up to three primary destinations plus a "More" button that opens
/// the full drawer. Selection is derived from the current route.
class _BottomNav extends ConsumerWidget {
  final VoidCallback onMore;
  const _BottomNav({required this.onMore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPath = GoRouterState.of(context).uri.path;
    final perms = ref.watch(permissionsProvider);

    // Which candidate routes are visible to this user?
    final visibleRoutes =
    _visibleEntries(perms).map((e) => e.route).toSet()..add('/');
    final primary = _bottomCandidates
        .where((c) => visibleRoutes.contains(c.route))
        .take(3)
        .toList();

    final moreIndex = primary.length;
    var selected = primary.indexWhere((c) => _isActive(currentPath, c.route));
    if (selected < 0) selected = moreIndex; // on a non-primary route → "More"

    return NavigationBar(
      selectedIndex: selected,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      onDestinationSelected: (i) {
        if (i == moreIndex) {
          onMore();
        } else {
          context.go(primary[i].route);
        }
      },
      destinations: [
        for (final c in primary)
          NavigationDestination(icon: Icon(c.icon), label: c.label),
        const NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
      ],
    );
  }
}

/// Small count pill reused by the sidebar tile and the rail tile.
class _NavBadge extends StatelessWidget {
  final int count;
  const _NavBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(9),
      ),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}