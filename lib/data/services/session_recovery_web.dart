import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import '../../core/constants/env.dart';

/// Web implementation: recover a pending OAuth session that was stashed in
/// sessionStorage before a redirect (e.g. magic-link / OAuth callback).
Future<void> recoverPendingWebAuth(SupabaseClient client) async {
  try {
    final stash = web.window.sessionStorage.getItem('sb-pending-auth-query');
    if (stash != null && stash.isNotEmpty) {
      web.window.sessionStorage.removeItem('sb-pending-auth-query');
      final params = Uri.splitQueryString(stash);
      final accessToken = params['access_token'];
      final refreshToken = params['refresh_token'];

      if (accessToken != null && refreshToken != null) {
        // Implicit flow — we have the tokens directly, set the session.
        await client.auth.setSession(refreshToken);
      } else if (params['code'] != null) {
        // PKCE flow — exchange the code via Supabase's URL handler.
        final url = Uri.parse('${Env.supabaseUrl}/?$stash');
        await client.auth.getSessionFromUrl(url);
      }
    }
  } catch (_) {
    // ignore — user can sign in normally if recovery fails
  }
}
