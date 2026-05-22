// lib/features/auth/providers/auth_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/models.dart';
import '../../../data/services/supabase_service.dart';

/// Streams auth state changes from Supabase.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.client.auth.onAuthStateChange;
});

/// The logged-in user's profile (joined from public.profiles).
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(authStateProvider);

  final user = SupabaseService.currentUser;
  if (user == null) return null;

  final row = await SupabaseService.client
      .from('profiles')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (row == null) return null;
  return Profile.fromMap(row);
});

/// Result of a sign-up attempt.
class SignUpResult {
  final bool needsEmailConfirmation;
  final String email;
  SignUpResult({
    required this.needsEmailConfirmation,
    required this.email,
  });
}

class AuthRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  /// Creates a new auth user AND sets up their agency + profile.
  ///
  /// Returns a [SignUpResult] indicating whether the user has a session
  /// (and was therefore set up immediately) or still needs to confirm
  /// their email.
  Future<SignUpResult> signUpAgencyAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String agencyName,
    required String agencyPhone,
    required String agencyState,
    String? agencyRcNumber,
  }) async {
    final res = await _c.auth.signUp(
      email: email,
      password: password,
    );

    if (res.user == null) {
      // This shouldn't happen — Supabase returns either a user or throws
      throw Exception('Could not create account. Please try again.');
    }

    // If we got a session, the user is signed in right now and we can
    // immediately set up their agency + profile.
    if (res.session != null) {
      try {
        await _c.rpc('complete_signup', params: {
          'p_full_name': fullName,
          'p_phone': phone,
          'p_agency_name': agencyName,
          'p_agency_phone': agencyPhone,
          'p_agency_state': agencyState,
          'p_agency_rc_number': agencyRcNumber,
        });
      } catch (e) {
        // The auth user was created but the agency setup failed.
        // We re-throw with a clearer message so the UI knows.
        throw Exception(
          'Account created but agency setup failed. '
              'Please contact support. (Details: $e)',
        );
      }
      return SignUpResult(
        needsEmailConfirmation: false,
        email: email,
      );
    }

    // No session means email confirmation is required. The auth user
    // was created, but we can't run complete_signup until they confirm
    // and log in (because the RPC needs auth.uid()).
    //
    // For now we return a pending result so the UI can show the
    // "check your email" screen. The user will need to confirm, sign in,
    // and then we'll set up their agency on first login.
    return SignUpResult(
      needsEmailConfirmation: true,
      email: email,
    );
  }

  /// Completes the agency + profile setup for a user who confirmed their
  /// email and is now signing in for the first time. Idempotent — safe
  /// to call repeatedly.
  Future<void> completeSignupIfNeeded({
    required String fullName,
    required String phone,
    required String agencyName,
    required String agencyPhone,
    required String agencyState,
    String? agencyRcNumber,
  }) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Check if profile already exists
    final existing = await _c
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return; // Already set up

    await _c.rpc('complete_signup', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_agency_name': agencyName,
      'p_agency_phone': agencyPhone,
      'p_agency_state': agencyState,
      'p_agency_rc_number': agencyRcNumber,
    });
  }

  Future<void> signOut() => _c.auth.signOut();
}

final authRepositoryProvider = Provider((_) => AuthRepository());