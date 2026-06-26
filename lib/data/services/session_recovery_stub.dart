import 'package:supabase_flutter/supabase_flutter.dart';

/// Default (non-web) implementation: no-op.
///
/// On web, a conditional import in supabase_service.dart swaps this out for
/// session_recovery_web.dart, which reads the pending OAuth query stashed in
/// sessionStorage after a redirect. On Android/iOS there is no sessionStorage
/// and no redirect stash, so there is nothing to recover.
Future<void> recoverPendingWebAuth(SupabaseClient client) async {
  // Intentionally empty on non-web platforms.
}
