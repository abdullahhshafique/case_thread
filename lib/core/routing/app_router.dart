import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/rooms/join_screen.dart';
import '../../features/rooms/room_detail_screen.dart';
import '../../features/rooms/rooms_screen.dart';
import '../../features/setup/setup_screen.dart';

/// Whether the app found Supabase credentials at bootstrap. Overridden in
/// main.dart (`config != null`) — never read from the Supabase singleton,
/// because `Supabase.instance` itself asserts when uninitialized.
final appConfiguredProvider = Provider<bool>((ref) {
  return false; // overridden in main; default keeps unconfigured safe.
});

/// Bridges the session stream into GoRouter's `refreshListenable` so the
/// redirect re-runs on every auth-state change (go_router 18 removed the
/// old `notifyListeners` workaround).
class _SessionRefreshListenable extends ChangeNotifier {
  _SessionRefreshListenable(Ref ref) {
    ref.listen(sessionProvider, (_, _) => notifyListeners());
  }
}

/// Route table + auth redirect (ExecutionPlan.md Sprint 1: unauthenticated
/// users land on auth; authenticated users go to their rooms).
///
/// When unconfigured, every route redirects to /setup so no provider ever
/// touches an uninitialized Supabase client.
final routerProvider = Provider<GoRouter>((ref) {
  final configured = ref.watch(appConfiguredProvider);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: _SessionRefreshListenable(ref),
    redirect: (context, state) {
      if (!configured) {
        return state.matchedLocation == '/setup' ? null : '/setup';
      }
      final signedIn = ref.read(sessionProvider).value != null;
      final isAuthRoute = state.matchedLocation == '/auth';
      if (!signedIn && !isAuthRoute) return '/auth';
      if (signedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
      GoRoute(path: '/', builder: (context, state) => const RoomsScreen()),
      GoRoute(path: '/join', builder: (context, state) => const JoinScreen()),
      GoRoute(
        path: '/rooms/:id',
        builder: (context, state) =>
            RoomDetailScreen(roomId: state.pathParameters['id']!),
      ),
    ],
  );

  // Keep the router alive as long as the app runs.
  ref.keepAlive();
  return router;
});
