import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'data/supabase_auth_repository.dart';
import 'domain/auth_repository.dart';
import 'presentation/auth_controller.dart';
export 'presentation/auth_controller.dart' show AuthMode;
export 'domain/auth_repository.dart' show AppUser, AuthRepository;

/// Supabase client. The singleton is initialized during bootstrap
/// (main.dart) only when config was present; this provider throws if read
/// before that — the router never builds auth/rooms routes when
/// unconfigured (PRD §6.7: no blank screens).
final supabaseClientProvider = Provider<supabase.SupabaseClient>((ref) {
  return supabase.Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Auth form controller (sign-in/sign-up mode + submission state). Reads
/// its repository from the container; the router's configured-redirect
/// guarantees the repository is only touched when Supabase is initialized.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Live session state (Architecture.md §8: stream providers wrapping
/// Supabase auth changes). While loading, `.value` is null — the router
/// treats loading and signed-out identically (auth screen), which avoids a
/// signed-in-user flash of the login form.
final sessionProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChanged;
});
