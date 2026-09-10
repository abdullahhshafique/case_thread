import 'dart:async';

/// Signed-in user as the client sees it — display name from the `profiles`
/// table (Architecture.md §5), identity from Supabase Auth.
class AppUser {
  const AppUser({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;
}

/// Auth contract every implementation fulfils (Supabase in production, a
/// fake in tests — Rules.md §7: mock external I/O, never business logic).
abstract class AuthRepository {
  /// Current signed-in user, or null when unauthenticated. Emits a new
  /// value on sign-in/out and session refresh.
  Stream<AppUser?> get onAuthStateChanged;

  /// Current user snapshot; null when unauthenticated.
  AppUser? get currentUser;

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<void> signOut();
}
