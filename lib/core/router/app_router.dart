// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/supabase_service.dart';
import '../widgets/lintel_splash.dart';
import '../../features/auth/presentation/screens/accept_invite_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/legal/presentation/legal_index_screen.dart';
import '../../features/legal/presentation/legal_doc_screen.dart';
import '../../features/email/presentation/screens/unsubscribe_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/clients/presentation/screens/client_detail_screen.dart';
import '../../features/clients/presentation/screens/clients_screen.dart';
import '../../features/clients/presentation/screens/onboard_client_screen.dart';
import '../../features/clients/presentation/screens/import_clients_screen.dart';
import '../../features/contracts/presentation/screens/contract_detail_screen.dart';
import '../../features/contracts/presentation/screens/contracts_screen.dart';
import '../../features/contracts/presentation/screens/new_contract_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/documents/presentation/screens/documents_screen.dart';
import '../../features/installments/presentation/screens/installments_screen.dart';
import '../../features/properties/presentation/screens/properties_screen.dart';
import '../../features/finances/presentation/screens/expenses_screen.dart';
import '../../features/finances/presentation/screens/income_screen.dart';
import '../../features/finances/presentation/screens/finance_report_screen.dart';
import '../../features/finances/presentation/screens/recurring_screen.dart';
import '../../features/properties/presentation/screens/property_detail_screen.dart';
import '../../features/reminders/presentation/screens/reminders_screen.dart';
import '../../features/settings/presentation/screens/signatures_settings_screen.dart';
import '../../features/billing/presentation/screens/billing_screen.dart';
import '../../features/settings/presentation/screens/settings_home_screen.dart';
import '../../features/signing/screens/signing_screen.dart';
import '../../features/staff/presentation/screens/staff_screen.dart';
import '../../features/properties/presentation/screens/new_property_screen.dart';
import '../../features/properties/presentation/screens/edit_property_screen.dart';
import '../../features/settings/presentation/screens/contract_template_screen.dart';
import '../../features/email/presentation/screens/email_settings_screen.dart';
import '../../features/shortlet/presentation/screens/booking_detail_screen.dart';
import '../../features/email/presentation/screens/email_campaigns_screen.dart';
import '../../features/email/presentation/screens/email_builder_screen.dart';
import '../../features/email/presentation/screens/email_audiences_screen.dart';
import '../../features/shortlet/presentation/screens/bookings_screen.dart';
import '../../features/shortlet/presentation/screens/new_booking_screen.dart';
import '../../features/email/presentation/screens/email_automations_screen.dart';

import 'app_shell.dart';

/// The single source of truth for navigation.
///
/// Public routes (no auth required):
///   /signin, /signup, /sign/:token, /forgot-password,
///   /reset-password, /accept-invite
///
/// All other routes are authenticated and rendered inside [AppShell]
/// (sidebar + topbar).
final routerProvider = Provider<GoRouter>((ref) {
  // Rebuild router when auth state flips (sign in / sign out / recovery).
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: kIsWeb ? '/' : '/splash',
    refreshListenable: _AuthChangeNotifier(ref),
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final user = SupabaseService.currentUser;
      final loggedIn = user != null;
      final path = state.uri.path;

      // ---------- Special cases first (no bouncing) ----------

      // Password recovery: user is "logged in" via recovery token,
      // but we want them to set a new password before anything else.
      // Cold-start splash (native only) plays before any auth gating.
      if (path == '/splash') return null;

      // Password recovery: user is "logged in" via recovery token,
      // but we want them to set a new password before anything else.
      if (path == '/reset-password') return null;

      // Invite acceptance: user is "logged in" via invite token,
      // but we want them to set their password first.
      if (path == '/accept-invite') return null;

      // Public signing page for clients (uses a per-document token,
      // no auth required).
      if (path.startsWith('/sign/')) return null;

      // Public unsubscribe page (recipients are not logged in; uses a
      // signed token in the query string).
      if (path == '/unsubscribe') return null;

      // Public legal documents (linkable from emails, signup, footer).
      if (path == '/legal' || path.startsWith('/legal/')) return null;

      // ---------- Invited user detection ----------
      //
      // If a logged-in user has invited_by metadata AND has not yet
      // set their password, force them to /accept-invite no matter
      // where they tried to go.
      if (loggedIn) {
        final meta = user.userMetadata ?? const {};
        final wasInvited = meta['invited_by'] != null;
        final passwordSet = meta['password_set'] == true;
        if (wasInvited && !passwordSet) {
          return '/accept-invite';
        }
      }

      // ---------- Normal auth gating ----------

      final isPublicAuthScreen = path == '/signin' ||
          path == '/signup' ||
          path == '/forgot-password';

      if (isPublicAuthScreen) {
        // Already signed in? Send them home.
        if (loggedIn) return '/';
        return null;
      }

      // Everything else needs auth.
      if (!loggedIn) return '/signin';
      return null;
    },
    routes: [
      // Cold-start animated splash; hands off to '/' (auth redirect decides).
      GoRoute(
        path: '/splash',
        builder: (context, __) => LintelSplashScreen(
          onComplete: () => context.go('/'),
        ),
      ),
      // -------------------- PUBLIC --------------------
      GoRoute(
        path: '/signin',
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: '/accept-invite',
        builder: (_, __) => const AcceptInviteScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/sign/:token',
        builder: (_, state) => SigningScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/legal',
        builder: (_, __) => const LegalIndexScreen(),
      ),
      GoRoute(
        path: '/legal/:slug',
        builder: (_, state) => LegalDocScreen(
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(
        path: '/unsubscribe',
        builder: (_, state) => UnsubscribeScreen(
          a: state.uri.queryParameters['a'],
          e: state.uri.queryParameters['e'],
          s: state.uri.queryParameters['s'],
        ),
      ),
      GoRoute(
        path: '/email/automations',
        builder: (_, __) => const EmailAutomationsScreen(),
      ),
      GoRoute(
        path: '/email/campaigns',
        builder: (_, __) => const EmailCampaignsScreen(),
      ),
      GoRoute(
        path: '/email/builder',
        builder: (_, __) => const EmailBuilderScreen(),
      ),
      GoRoute(
        path: '/email/audiences',
        builder: (_, __) => const EmailAudiencesScreen(),
      ),

      // -------------------- AUTHENTICATED --------------------
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsHomeScreen(),
          ),
          GoRoute(
            path: '/settings/billing',
            builder: (_, __) => const BillingScreen(),
          ),
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
            path: '/clients/import',
            builder: (_, __) => const ImportClientsScreen(),
          ),
          GoRoute(
            path: '/clients/:id',
            builder: (_, state) => ClientDetailScreen(
              clientId: state.pathParameters['id']!,
            ),
          ),

          GoRoute(
            path: '/settings/contract-template',
            builder: (_, __) => const ContractTemplateScreen(),
          ),

          // Properties
          GoRoute(
            path: '/properties',
            builder: (_, __) => const PropertiesScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/income',
            builder: (_, __) => const IncomeScreen(),
          ),
          GoRoute(
            path: '/pnl',
            builder: (_, __) => const FinanceReportScreen(),
          ),
          GoRoute(
            path: '/recurring',
            builder: (_, __) => const RecurringScreen(),
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
          GoRoute(
            path: '/properties/:id/edit',
            builder: (_, state) => EditPropertyScreen(
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
            path: '/email/settings',
            builder: (_, __) => const EmailSettingsScreen(),
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
          GoRoute(
            path: '/bookings',
            builder: (_, __) => const BookingsScreen(),
          ),
          GoRoute(
            path: '/bookings/new',
            builder: (_, __) => const NewBookingScreen(),
          ),
          GoRoute(
            path: '/bookings/:id',
            builder: (_, state) => BookingDetailScreen(
              bookingId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});

/// Notifies the router whenever the Supabase auth state changes,
/// so the redirect logic re-runs. Also listens for PASSWORD_RECOVERY
/// events and pushes the user to /reset-password.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, next) {
      notifyListeners();
      next.whenData((authState) {
        // Password recovery → reset screen
        if (authState.event == AuthChangeEvent.passwordRecovery) {
          _navigate('/reset-password');
        }
        // (Invited users are handled by the redirect function itself,
        // so we don't need a listener for that.)
      });
    });
  }

  void _navigate(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _routerCtx;
      if (ctx != null && ctx.mounted) {
        ctx.go(path);
      }
    });
  }
}

/// Captured from AppShell on first build so we can navigate from
/// outside the widget tree (e.g. in response to auth events).
BuildContext? _routerCtx;

/// Called from AppShell.build() to capture a routed context for use
/// in auth-event handlers (e.g. password recovery) that fire outside
/// the widget tree.
void captureRouterContext(BuildContext context) {
  _routerCtx ??= context;
}