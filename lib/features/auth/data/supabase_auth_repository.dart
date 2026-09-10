import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_mapper.dart';
import '../domain/auth_repository.dart' as domain;

/// Supabase-backed auth repository. Email/password auth (PRD §6.1,
/// Architecture.md §4 auth module); session persistence handled by the
/// Supabase client SDK.
///
/// The supabase import is prefixed because gotrue exports `AuthException`
/// and `AuthState`, which collide with our own typed-error and UI-state
/// names — our domain terms always win unprefixed.
class SupabaseAuthRepository implements domain.AuthRepository {
  SupabaseAuthRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Stream<domain.AppUser?> get onAuthStateChanged {
    return _client.auth.onAuthStateChange.map((state) {
      final user = state.session?.user;
      return user == null ? null : _toAppUser(user);
    });
  }

  @override
  domain.AppUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<domain.AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': displayName},
      );
      final user = response.user;
      if (user == null) {
        // Null user = email confirmation required and auto-sign-in off —
        // the account exists; tell them to confirm rather than failing.
        throw const AuthValidationException(
          message:
              'Account created. Check your email for a confirmation link '
              'before signing in.',
        );
      }
      return _toAppUser(user, displayNameOverride: displayName);
    } on AppException {
      rethrow;
    } on supabase.AuthException catch (error) {
      throw AuthException.fromSupabase(error);
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<domain.AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException(message: 'Sign-in failed. Please try again.');
      }
      return _toAppUser(user);
    } on AppException {
      rethrow;
    } on supabase.AuthException catch (error) {
      throw AuthException.fromSupabase(error);
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> signOut() async {
    // Scope.local clears this device's session even if the server call
    // fails — signing out must never trap the user in an unusable state.
    await _client.auth.signOut();
  }

  domain.AppUser _toAppUser(supabase.User user, {String? displayNameOverride}) {
    final meta = user.userMetadata;
    return domain.AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName:
          displayNameOverride ??
          (meta?['display_name'] as String?) ??
          (user.email ?? '').split('@').first,
    );
  }
}
