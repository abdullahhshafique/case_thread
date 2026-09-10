import 'dart:async';

import 'package:case_thread/features/auth/domain/auth_repository.dart';

/// In-memory fake for tests (Rules.md §7: mock external I/O, never the
/// business logic under test).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.signedInUser});

  AppUser? signedInUser;

  /// When non-null, [signIn] throws this instead of succeeding.
  Object? signInError;

  /// When non-null, [signUp] throws this instead of succeeding.
  Object? signUpError;

  final List<String> signInCalls = [];
  final List<String> signUpCalls = [];

  final _controller = StreamController<AppUser?>.broadcast();

  @override
  Stream<AppUser?> get onAuthStateChanged => _controller.stream;

  @override
  AppUser? get currentUser => signedInUser;

  void emit(AppUser? user) {
    signedInUser = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls.add(email);
    if (signInError != null) throw signInError!;
    final user = AppUser(id: 'user-1', email: email);
    emit(user);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    signUpCalls.add(email);
    if (signUpError != null) throw signUpError!;
    final user = AppUser(id: 'user-2', email: email, displayName: displayName);
    emit(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    emit(null);
  }

  void dispose() => _controller.close();
}
