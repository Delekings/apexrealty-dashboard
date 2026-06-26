import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/env.dart';
// Conditional import: the stub (no-op) is used everywhere by default; on web
// (where dart.library.html exists) the real package:web implementation is
// selected instead. This keeps package:web / dart:js_interop out of the
// Android & iOS compile entirely.
import 'session_recovery_stub.dart'
    if (dart.library.html) 'session_recovery_web.dart';

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

    // No-op on native; recovers a stashed OAuth redirect on web.
    await recoverPendingWebAuth(client);
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get session => client.auth.currentSession;
}
