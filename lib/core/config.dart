import 'package:flutter/foundation.dart';

/// Centralisation de la configuration et des secrets.
/// En production, utilisez --dart-define pour injecter les clés :
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iquozfjxaiakihplymuv.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_vhL-xeXcEyO9ubrbQM62Ng_inBeVurW',
  );

  static bool get isProduction => kReleaseMode;
}
