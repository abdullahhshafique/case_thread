import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root widget: theme + router. The configured/unconfigured decision is
/// made inside [routerProvider] by checking the Supabase singleton, so this
/// widget stays stateless about bootstrap concerns.
class CaseThreadApp extends ConsumerWidget {
  const CaseThreadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CaseThread',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
