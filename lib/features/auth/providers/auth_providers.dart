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

  /// Creates a new auth user. The agency + profile are created
  /// automatically by the `on_auth_user_created` Postgres trigger on
  /// `auth.users`, reading the agency/profile data from `raw_user_meta_data`.
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
      data: {
        'full_name': fullName,
        'phone': phone,
        'agency_name': agencyName,
        'agency_phone': agencyPhone,
        'agency_state': agencyState,
        if (agencyRcNumber != null && agencyRcNumber.trim().isNotEmpty)
          'agency_rc_number': agencyRcNumber,
      },
    );

    if (res.user == null) {
      throw Exception('Could not create account. Please try again.');
    }

    if (res.session != null) {
      try {
        final existing = await _c
            .from('profiles')
            .select('id')
            .eq('id', res.user!.id)
            .maybeSingle();
        if (existing == null) {
          await _c.rpc('complete_signup', params: {
            'p_full_name': fullName,
            'p_phone': phone,
            'p_agency_name': agencyName,
            'p_agency_phone': agencyPhone,
            'p_agency_state': agencyState,
            'p_agency_rc_number': agencyRcNumber,
          });
        }
      } catch (_) {}
      return SignUpResult(needsEmailConfirmation: false, email: email);
    }

    return SignUpResult(needsEmailConfirmation: true, email: email);
  }

  /// Verifies the 6-digit email confirmation code sent after sign-up.
  /// On success the account is confirmed AND a session is created (the
  /// user is signed in) — no email link or redirect needed. This is the
  /// flow used by the registration screen, and works well on mobile.
  Future<void> verifySignupCode({
    required String email,
    required String code,
  }) async {
    await _c.auth.verifyOTP(
      email: email.trim(),
      token: code.trim(),
      type: OtpType.signup,
    );
  }

  /// Re-sends the sign-up confirmation code to [email].
  Future<void> resendSignupCode(String email) async {
    await _c.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  /// Sends a password reset email. The link in the email will redirect
  /// the user to /reset-password where they set a new password.
  Future<void> requestPasswordReset(String email) async {
    await _c.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'https://app.getlintel.org/#/reset-password',
    );
  }

  /// Updates the password for the currently-recovering user. Called
  /// from the /reset-password screen after the user lands there from
  /// the email link (Supabase fires a PASSWORD_RECOVERY event which
  /// puts them in a recovery session that allows updateUser).
  Future<void> updatePassword(String newPassword) async {
    await _c.auth.updateUser(UserAttributes(password: newPassword));
  }

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

    final existing = await _c
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return;

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