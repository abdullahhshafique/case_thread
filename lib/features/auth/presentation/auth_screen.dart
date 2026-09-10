import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../auth_providers.dart';
import 'auth_controller.dart';

/// Sign-in / sign-up screen (PRD §6.1: authenticated before any room
/// activity; Architecture.md §7 login flow).
///
/// Form labels are persistent, not placeholder-only (Design.md §11).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // Obscured by default; the reveal toggle is an accessible toggle button
  // with a semantics label (Design.md §5 icon rules).
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isSignUp =
        state is AuthIdle && state.mode == AuthMode.signUp ||
        state is AuthSubmitting && state.mode == AuthMode.signUp;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CaseThread',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    isSignUp
                        ? 'Create your account'
                        : 'Sign in to your case rooms',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (isSignUp) ...[
                    _nameField(),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _emailField(),
                  const SizedBox(height: AppSpacing.md),
                  _passwordField(),
                  if (state is AuthError) ...[
                    const SizedBox(height: AppSpacing.md),
                    _errorMessage(state),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _submitButton(state),
                  const SizedBox(height: AppSpacing.md),
                  _modeSwitch(isSignUp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextFormField(
      key: const Key('auth-name-field'),
      controller: _nameController,
      autofillHints: const [AutofillHints.name],
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Display name',
        hintText: 'How your team will see you',
      ),
      validator: (value) {
        final name = value?.trim() ?? '';
        if (name.isEmpty) return 'Enter a display name.';
        if (name.length > 80) return 'Keep it under 80 characters.';
        return null;
      },
    );
  }

  Widget _emailField() {
    return TextFormField(
      key: const Key('auth-email-field'),
      controller: _emailController,
      autofillHints: const [AutofillHints.email],
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'you@example.com',
      ),
      validator: (value) {
        final email = value?.trim() ?? '';
        if (email.isEmpty) return 'Enter your email address.';
        final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
        if (!pattern.hasMatch(email)) {
          return 'That doesn\'t look like a valid email address.';
        }
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      key: const Key('auth-password-field'),
      controller: _passwordController,
      obscureText: _obscurePassword,
      autofillHints: const [AutofillHints.password],
      onFieldSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'At least 6 characters',
        suffixIcon: Semantics(
          label: _obscurePassword ? 'Show password' : 'Hide password',
          child: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () => setState(() {
              _obscurePassword = !_obscurePassword;
            }),
          ),
        ),
      ),
      validator: (value) {
        final password = value ?? '';
        if (password.isEmpty) return 'Enter a password.';
        if (password.length < 6) {
          return 'Passwords are at least 6 characters.';
        }
        return null;
      },
    );
  }

  Widget _errorMessage(AuthError state) {
    return Row(
      key: const Key('auth-error'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.error_outline,
          size: 20,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            state.error.message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _submitButton(AuthState state) {
    final submitting = state.isSubmitting;
    return ElevatedButton(
      key: const Key('auth-submit'),
      onPressed: submitting ? null : _submit,
      child: submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_isSignUpMode(state) ? 'Create account' : 'Sign in'),
    );
  }

  Widget _modeSwitch(bool isSignUp) {
    return TextButton(
      key: const Key('auth-mode-switch'),
      onPressed: () {
        ref
            .read(authControllerProvider.notifier)
            .setMode(isSignUp ? AuthMode.signIn : AuthMode.signUp);
      },
      child: Text(
        isSignUp
            ? 'Already have an account? Sign in'
            : 'New here? Create an account',
      ),
    );
  }

  bool _isSignUpMode(AuthState state) => switch (state) {
    AuthIdle(mode: final m) => m == AuthMode.signUp,
    AuthSubmitting(mode: final m) => m == AuthMode.signUp,
    AuthError(mode: final m) => m == AuthMode.signUp,
  };

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    ref
        .read(authControllerProvider.notifier)
        .submit(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
  }
}
