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

class AuthRepository {
  final SupabaseClient _c = SupabaseService.client;

  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email, password: password);
  }

  /// Creates a new auth user AND sets up their agency + profile.
  Future<void> signUpAgencyAdmin({
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
      throw Exception('Could not create account. Please try again.');
    }

    if (res.session == null) {
      throw Exception(
          'We sent a verification link to $email. Please verify your email, then sign in.');
    }

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