import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../../core/constants/env.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    if (kIsWeb) {
      try {
        final stash = web.window.sessionStorage.getItem('sb-pending-auth-query');
        if (stash != null && stash.isNotEmpty) {
          web.window.sessionStorage.removeItem('sb-pending-auth-query');
          final params = Uri.splitQueryString(stash);
          final accessToken = params['access_token'];
          final refreshToken = params['refresh_token'];

          if (accessToken != null && refreshToken != null) {
            // Implicit flow — we have the tokens directly, set the session
            await Supabase.instance.client.auth.setSession(refreshToken);
          } else if (params['code'] != null) {
            // PKCE flow — exchange the code via Supabase's URL handler
            final url = Uri.parse('${Env.supabaseUrl}/?$stash');
            await Supabase.instance.client.auth.getSessionFromUrl(url);
          }
        }
      } catch (e) {
        // ignore — user can sign in normally if recovery fails
      }
    }
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get session => client.auth.currentSession;
}