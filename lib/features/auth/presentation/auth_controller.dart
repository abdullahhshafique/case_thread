import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exceptions.dart';
import '../auth_providers.dart';

/// Auth form mode: existing-user sign-in vs account creation.
enum AuthMode { signIn, signUp }

/// Auth UI state: form mode plus the in-flight submission state.
sealed class AuthState {
  const AuthState({required this.mode});

  final AuthMode mode;

  bool get isSubmitting => this is AuthSubmitting;
}

final class AuthIdle extends AuthState {
  const AuthIdle({required super.mode});
}

final class AuthSubmitting extends AuthState {
  const AuthSubmitting({required super.mode});
}

final class AuthError extends AuthState {
  const AuthError({required super.mode, required this.error});

  final AppException error;
}

/// Controller for the auth screen form. Session state lives in
/// [sessionProvider]; this notifier only owns the form lifecycle.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => AuthIdle(mode: AuthMode.signIn);

  AuthRepository get _repository => ref.read(authRepositoryProvider);

  void setMode(AuthMode newMode) {
    if (state.mode != newMode || state is! AuthIdle) {
      state = AuthIdle(mode: newMode);
    }
  }

  Future<void> submit({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final mode = state.mode;
    state = AuthSubmitting(mode: mode);

    try {
      if (mode == AuthMode.signUp) {
        await _repository.signUp(
          email: email,
          password: password,
          displayName: displayName ?? email.split('@').first,
        );
      } else {
        await _repository.signIn(email: email, password: password);
      }
      // Success: sessionProvider emits and the router redirect moves the
      // user off the auth screen. Return to idle so the submit button is
      // usable if the redirect is delayed (e.g. slow stream delivery).
      state = AuthIdle(mode: mode);
    } on AppException catch (error) {
      state = AuthError(mode: mode, error: error);
    }
  }
}
