import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Config from --dart-define (web/CI) or .env (local device/desktop);
  // null → setup screen, never a crash (PRD §6.7).
  final config = await AppConfig.load();
  if (config != null) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        // Tell the router whether a backend exists without ever touching
        // Supabase.instance (which asserts when uninitialized).
        appConfiguredProvider.overrideWith((ref) => config != null),
      ],
      child: const CaseThreadApp(),
    ),
  );
}
