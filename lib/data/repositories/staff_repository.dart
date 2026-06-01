// lib/data/repositories/staff_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class StaffMember {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role; // agency_admin | manager | accountant | agent
  final bool isExternal;
  final double? commissionRatePct;
  final bool isActive;
  final DateTime? lastSeenAt;
  final DateTime? invitedAt;
  final DateTime createdAt;
  final int clientsCount;
  final int contractsCount;
  final num commissionPendingNgn;
  final num commissionPaidNgn;

  StaffMember({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isExternal,
    required this.isActive,
    required this.createdAt,
    required this.clientsCount,
    required this.contractsCount,
    required this.commissionPendingNgn,
    required this.commissionPaidNgn,
    this.email,
    this.phone,
    this.commissionRatePct,
    this.lastSeenAt,
    this.invitedAt,
  });

  factory StaffMember.fromMap(Map<String, dynamic> m) => StaffMember(
    id: m['id'] as String,
    fullName: m['full_name'] as String,
    email: m['email'] as String?,
    phone: m['phone'] as String?,
    role: m['role'] as String,
    isExternal: (m['is_external'] as bool?) ?? false,
    commissionRatePct: (m['commission_rate_pct'] as num?)?.toDouble(),
    isActive: (m['is_active'] as bool?) ?? true,
    lastSeenAt: m['last_seen_at'] != null
        ? DateTime.parse(m['last_seen_at'] as String)
        : null,
    invitedAt: m['invited_at'] != null
        ? DateTime.parse(m['invited_at'] as String)
        : null,
    createdAt: DateTime.parse(m['created_at'] as String),
    clientsCount: (m['clients_count'] as num?)?.toInt() ?? 0,
    contractsCount: (m['contracts_count'] as num?)?.toInt() ?? 0,
    commissionPendingNgn: (m['commission_pending_ngn'] as num?) ?? 0,
    commissionPaidNgn: (m['commission_paid_ngn'] as num?) ?? 0,
  );

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String get roleLabel {
    if (role == 'agency_admin') return 'Admin';
    if (role == 'manager') return 'Manager';
    if (role == 'accountant') return 'Accountant';
    if (role == 'agent') return isExternal ? 'Marketer' : 'Sales Agent';
    return role;
  }
}

class StaffRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<List<StaffMember>> list() async {
    final rows = await _c
        .from('staff_with_stats')
        .select()
        .order('created_at', ascending: true);
    return (rows as List)
        .map((r) => StaffMember.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> invite({
    required String email,
    required String fullName,
    required String role,
    bool isExternal = false,
    double? commissionRatePct,
  }) async {
    try {
      final res = await _c.functions.invoke(
        'invite-staff',
        body: {
          'email': email,
          'full_name': fullName,
          'role': role,
          'is_external': isExternal,
          'commission_rate_pct': commissionRatePct,
        },
      );
      if (res.status != 200) {
        final err = (res.data is Map ? res.data['error'] : null) ??
            'Invite failed (status ${res.status})';
        throw Exception(err);
      }
    } on FunctionException catch (e) {
      // Edge function returned a non-2xx — pull out the actual error message
      final details = e.details;
      String msg = 'Invite failed';
      if (details is Map && details['error'] != null) {
        msg = details['error'].toString();
      } else if (details != null) {
        msg = details.toString();
      } else if (e.reasonPhrase != null && e.reasonPhrase!.isNotEmpty) {
        msg = e.reasonPhrase!;
      }
      throw Exception(msg);
    }
  }

  Future<void> updateRole({
    required String userId,
    required String newRole,
    bool? isExternal,
    double? commissionRatePct,
  }) async {
    final patch = <String, dynamic>{'role': newRole};
    if (isExternal != null) patch['is_external'] = isExternal;
    if (commissionRatePct != null) {
      patch['commission_rate_pct'] = commissionRatePct;
    }
    await _c.from('profiles').update(patch).eq('id', userId);
  }

  Future<void> setActive(String userId, bool active) async {
    await _c.from('profiles').update({'is_active': active}).eq('id', userId);
  }
}

final staffRepoProvider = Provider((_) => StaffRepository());

final staffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  return ref.read(staffRepoProvider).list();
});