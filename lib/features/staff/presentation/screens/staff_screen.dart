// lib/features/staff/presentation/screens/staff_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/repositories/staff_repository.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../widgets/invite_staff_dialog.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.role.name == 'agencyAdmin';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Team',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                    SizedBox(height: 4),
                    Text(
                      'Invite staff, manage roles, track performance.',
                      style:
                      TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                FilledButton.icon(
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Invite team member'),
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const InviteStaffDialog(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: staffAsync.when(
              loading: () =>
              const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load staff: $e',
                    style: const TextStyle(color: AppColors.danger)),
              ),
              data: (staff) => _StaffList(staff: staff, isAdmin: isAdmin),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffList extends ConsumerWidget {
  final List<StaffMember> staff;
  final bool isAdmin;
  const _StaffList({required this.staff, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (staff.isEmpty) {
      return const Center(child: Text('No staff yet.'));
    }
    return ListView.separated(
      itemCount: staff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _StaffRow(member: staff[i], isAdmin: isAdmin),
    );
  }
}

class _StaffRow extends ConsumerWidget {
  final StaffMember member;
  final bool isAdmin;
  const _StaffRow({required this.member, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.brandLight,
            child: Text(member.initials,
                style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.fullName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 8),
                    _rolePill(member),
                    if (!member.isActive) ...[
                      const SizedBox(width: 6),
                      _pill('Inactive', AppColors.muted),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  member.email ?? '—',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (member.role == 'agent') ...[
            _stat('${member.clientsCount}', 'clients'),
            const SizedBox(width: 14),
            _stat('₦${_fmt(member.commissionPendingNgn)}', 'pending'),
            const SizedBox(width: 14),
          ],
          if (isAdmin && member.role != 'agency_admin')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) => _handleAction(context, ref, v),
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'change_role', child: Text('Change role')),
                PopupMenuItem(
                  value: member.isActive ? 'deactivate' : 'reactivate',
                  child: Text(member.isActive ? 'Deactivate' : 'Reactivate'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rolePill(StaffMember m) {
    final color = switch (m.role) {
      'agency_admin' => AppColors.brand,
      'manager' => Colors.blue,
      'accountant' => Colors.purple,
      _ => m.isExternal ? Colors.orange : AppColors.muted,
    };
    return _pill(m.roleLabel, color);
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }

  Future<void> _handleAction(
      BuildContext context, WidgetRef ref, String action) async {
    if (action == 'deactivate' || action == 'reactivate') {
      await ref
          .read(staffRepoProvider)
          .setActive(member.id, action == 'reactivate');
      ref.invalidate(staffListProvider);
    } else if (action == 'change_role') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Role editing coming in next update')));
    }
  }

  String _fmt(num n) {
    if (n == 0) return '0';
    final s = n.toStringAsFixed(0);
    return s.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}