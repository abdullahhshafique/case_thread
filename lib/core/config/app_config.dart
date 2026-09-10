import 'package:flutter/foundation.dart' show kIsWeb;

import 'env_reader_stub.dart'
    if (dart.library.io) 'env_reader_io.dart'
    if (dart.library.html) 'env_reader_web.dart'
    as env_reader;

/// Environment-aware Supabase configuration (Architecture.md §10:
/// environment-specific config injected at build time, never hardcoded).
///
/// Values come from compile-time defines (`--dart-define`) — the required
/// path for web — falling back to a local `.env` file on non-web platforms
/// where runtime file access exists. See `.env.example`.
enum AppFlavor { dev, staging, prod }

class AppConfig {
  const AppConfig._({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  /// Loads config for this runtime. Returns `null` when the app is
  /// unconfigured (no URL/key) — the UI then shows the setup screen rather
  /// than crashing (PRD §6.7: never a blank screen or raw failure).
  static Future<AppConfig?> load() async {
    const flavorName = String.fromEnvironment('APP_FLAVOR');
    final flavor = AppFlavor.values.firstWhere(
      (f) => f.name == flavorName,
      orElse: () => AppFlavor.dev,
    );

    var url = const String.fromEnvironment('SUPABASE_URL');
    var key = const String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty && !kIsWeb) {
      final envFile = await env_reader.readDotEnv('.env');
      url = envFile['SUPABASE_URL'] ?? url;
      key = key.isNotEmpty ? key : (envFile['SUPABASE_ANON_KEY'] ?? key);
    }

    if (url.isEmpty || key.isEmpty) return null;
    return AppConfig._(flavor: flavor, supabaseUrl: url, supabaseAnonKey: key);
  }

  final AppFlavor flavor;
  final String supabaseUrl;
  final String supabaseAnonKey;
}
