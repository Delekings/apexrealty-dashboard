// lib/core/auth/permissions.dart
//
// Single source of truth for who can do what in the app.
// All UI gating reads from these helpers — never check role strings directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../features/auth/providers/auth_providers.dart';

/// All discrete actions/screens that can be gated.
enum Permission {
  // Staff & agency settings (admin-only)
  manageStaff,
  manageAgencySettings,
  manageContractTemplate,
  manageSignatures,
  manageEmailSettings,

  // Money operations
  recordPayment,
  viewAllPayments,
  exportFinancials,

  // Client/contract operations
  createClient,
  editAnyClient,
  editOwnClients,
  deleteClient,

  createContract,
  signContract,

  // Property/listing operations
  manageProperties,
  manageRentalListings,

  // Booking operations
  createBooking,
  checkInGuest,
  cancelBooking,

  // Marketer-specific
  viewOwnCommissions,
}

/// Permission set for the current user, computed from their role + is_external flag.
class PermissionSet {
  final UserRole role;
  final bool isExternal;
  const PermissionSet({required this.role, required this.isExternal});

  bool can(Permission p) {
    // External agents (marketers) have a very narrow surface
    if (isExternal && role == UserRole.agent) {
      return _marketerPerms.contains(p);
    }

    switch (role) {
      case UserRole.superAdmin:
      case UserRole.agencyAdmin:
        return true; // can do everything
      case UserRole.manager:
        return _managerPerms.contains(p);
      case UserRole.accountant:
        return _accountantPerms.contains(p);
      case UserRole.agent:
        return _agentPerms.contains(p);
      case UserRole.viewer:
        return false; // read-only, no permissions for write actions
    }
  }

  // Convenience getters
  bool get isAdmin =>
      role == UserRole.agencyAdmin || role == UserRole.superAdmin;
  bool get isManagerOrAbove => isAdmin || role == UserRole.manager;
  bool get isAccountant => role == UserRole.accountant;
  bool get isMarketer => isExternal && role == UserRole.agent;
  bool get isAgent => role == UserRole.agent && !isExternal;

  static const _managerPerms = {
    Permission.recordPayment,
    Permission.viewAllPayments,
    Permission.exportFinancials,
    Permission.createClient,
    Permission.editAnyClient,
    Permission.editOwnClients,
    Permission.deleteClient,
    Permission.createContract,
    Permission.signContract,
    Permission.manageProperties,
    Permission.manageRentalListings,
    Permission.createBooking,
    Permission.checkInGuest,
    Permission.cancelBooking,
  };

  static const _accountantPerms = {
    Permission.recordPayment,
    Permission.viewAllPayments,
    Permission.exportFinancials,
  };

  static const _agentPerms = {
    Permission.createClient,
    Permission.editOwnClients,
    Permission.createContract,
    Permission.createBooking,
    Permission.checkInGuest,
  };

  static const _marketerPerms = {
    Permission.viewOwnCommissions,
  };
}

/// The current user's permission set. Watch this anywhere you need to gate.
final permissionsProvider = Provider<PermissionSet>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) {
    // Most-restrictive default while loading
    return const PermissionSet(role: UserRole.viewer, isExternal: false);
  }
  return PermissionSet(
    role: profile.role,
    isExternal: profile.isExternal ?? false,
  );
});

/// Convenience: `ref.watch(canProvider(Permission.manageStaff))`.
final canProvider = Provider.family<bool, Permission>((ref, perm) {
  return ref.watch(permissionsProvider).can(perm);
});