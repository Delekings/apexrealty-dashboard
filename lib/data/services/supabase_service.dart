// lib/data/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }

  static User? get currentUser => client.auth.currentUser;
  static Session? get session => client.auth.currentSession;
}
