// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/supabase_service.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/clients/presentation/screens/clients_screen.dart';
import '../../features/clients/presentation/screens/onboard_client_screen.dart';
import '../../features/contracts/presentation/screens/contract_detail_screen.dart';
import '../../features/contracts/presentation/screens/contracts_screen.dart';
import '../../features/contracts/presentation/screens/new_contract_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/installments/presentation/screens/installments_screen.dart';
import '../../features/properties/presentation/screens/add_property_screen.dart';
import '../../features/properties/presentation/screens/properties_screen.dart';
import '../../features/properties/presentation/screens/property_detail_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/settings/presentation/screens/signatures_settings_screen.dart';
import '../../features/signing/screens/signing_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/properties/presentation/screens/new_property_screen.dart';

import 'app_shell.dart';

/// The single source of truth for navigation.
///
/// Public routes (no auth required):
///   /signin, /signup, /sign/:token
///
/// All other routes are authenticated and rendered inside [AppShell]
/// (sidebar + topbar). The redirect logic below enforces this.
final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild router when auth state flips (sign in / sign out).
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthChangeNotifier(ref),
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final loggedIn = SupabaseService.currentUser != null;
      final path = state.uri.path;

      final isPublic = path.startsWith('/sign/') ||
          path == '/signin' ||
          path == '/signup';

      if (isPublic) {
        // Already signed in? Skip the auth screens.
        if (loggedIn && (path == '/signin' || path == '/signup')) {
          return '/';
        }
        return null;
      }

      // Anything else requires auth.
      if (!loggedIn) return '/signin';
      return null;
    },
    routes: [
      // -------------------- PUBLIC --------------------
      GoRoute(
        path: '/signin',
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/sign/:token',
        builder: (_, state) => SigningScreen(
          token: state.pathParameters['token']!,
        ),
      ),

      // -------------------- AUTHENTICATED --------------------
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/settings/signatures',
            builder: (_, __) => const SignaturesSettingsScreen(),
          ),
          GoRoute(
            path: '/',
            builder: (_, __) => const DashboardScreen(),
          ),

          // Clients
          GoRoute(
            path: '/clients',
            builder: (_, __) => const ClientsScreen(),
          ),
          GoRoute(
            path: '/clients/new',
            builder: (_, __) => const OnboardClientScreen(),
          ),
          GoRoute(
            path: '/clients/:id',
            builder: (_, state) => ClientDetailScreen(
              clientId: state.pathParameters['id']!,
            ),
          ),

          // Properties
          GoRoute(
            path: '/properties',
            builder: (_, __) => const PropertiesScreen(),
          ),
          GoRoute(
            path: '/properties/new',
            builder: (_, __) => const NewPropertyScreen(),
          ),
          GoRoute(
            path: '/properties/:id',
            builder: (_, state) => PropertyDetailScreen(
              propertyId: state.pathParameters['id']!,
            ),
          ),

          // Contracts
          GoRoute(
            path: '/contracts',
            builder: (_, __) => const ContractsScreen(),
          ),
          GoRoute(
            path: '/contracts/new',
            builder: (_, state) => NewContractScreen(
              propertyId: state.uri.queryParameters['property'],
              unitTypeId: state.uri.queryParameters['unit_type'],
            ),
          ),
          GoRoute(
            path: '/contracts/:id',
            builder: (_, state) => ContractDetailScreen(
              contractId: state.pathParameters['id']!,
            ),
          ),

          // Other modules
          GoRoute(
            path: '/installments',
            builder: (_, __) => const InstallmentsScreen(),
          ),
          GoRoute(
            path: '/documents',
            builder: (_, __) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/reminders',
            builder: (_, __) => const RemindersScreen(),
          ),
          GoRoute(
            path: '/staff',
            builder: (_, __) => const StaffScreen(),
          ),
        ],
      ),
    ],
  );
});

/// Notifies the router whenever the Supabase auth state changes,
/// so the redirect logic re-runs.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}