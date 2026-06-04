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

    // After init, check if our JS shim stashed auth params from a mangled
    // invite/recovery URL. If so, recover the session manually.
    if (kIsWeb) {
      try {
        final stash = web.window.sessionStorage.getItem('sb-pending-auth-query');
        if (stash != null && stash.isNotEmpty) {
          web.window.sessionStorage.removeItem('sb-pending-auth-query');
          // Construct a clean URL with the recovered query so supabase-flutter
          // can finish the PKCE exchange.
          final url = Uri.parse(
            '${Env.supabaseUrl}/?$stash',
          );
          await Supabase.instance.client.auth.getSessionFromUrl(url);
        }
      } catch (_) {
        // Recovery best-effort. If it fails, user will land on /signin and
        // can request a fresh invite.
      }
    }
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get session => client.auth.currentSession;
}