// lib/core/constants/env.dart
//
// Replace these with your real Supabase project URL and anon key,
// or load them at build time via --dart-define:
//   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://dzgtzvbrafdnvgnvwnkb.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6Z3R6dmJyYWZkbnZnbnZ3bmtiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0MzkyNjIsImV4cCI6MjA5NDAxNTI2Mn0.dNv-oV2LIcA15S0lZCx7K5cHIw3nysYAHUN6jB3DWbI',
  );

  // For DocuSign integration we never put the secret in the client;
  // edge function URL is fine to expose.
  static const docusignEdgeFnUrl = String.fromEnvironment(
    'DOCUSIGN_EDGE_FN',
    defaultValue: '',
  );

  static const termiiEdgeFnUrl = String.fromEnvironment(
    'TERMII_EDGE_FN',
    defaultValue: '',
  );
}
