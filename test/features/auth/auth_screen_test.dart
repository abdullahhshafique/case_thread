import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/errors/app_exceptions.dart';
import 'package:case_thread/features/auth/auth_providers.dart';
import 'package:case_thread/features/auth/presentation/auth_screen.dart';

import 'fake_auth_repository.dart';

/// Auth form behaviour (Rules.md §7): validation, mode switching, error
/// rendering, and submission wiring to the repository.
void main() {
  late FakeAuthRepository repo;

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => repo),
        // The controller reads authRepositoryProvider via ref.read — same
        // override applies through the container.
      ],
      child: const MaterialApp(home: AuthScreen()),
    );
  }

  setUp(() {
    repo = FakeAuthRepository();
  });

  testWidgets('starts in sign-in mode with labeled fields', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-password-field')), findsOneWidget);
    // No name field in sign-in mode.
    expect(find.byKey(const Key('auth-name-field')), findsNothing);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('switching to sign-up shows the name field', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.tap(find.byKey(const Key('auth-mode-switch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-name-field')), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('invalid email is rejected client-side', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'not-an-email',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    // Validation message shown, repository never called.
    expect(
      find.text('That doesn\'t look like a valid email address.'),
      findsOneWidget,
    );
    expect(repo.signInCalls, isEmpty);
  });

  testWidgets('short password is rejected client-side', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'aadi@example.com',
    );
    await tester.enterText(find.byKey(const Key('auth-password-field')), '123');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('Passwords are at least 6 characters.'), findsOneWidget);
    expect(repo.signInCalls, isEmpty);
  });

  testWidgets('successful sign-in calls the repository', (tester) async {
    await tester.pumpWidget(buildApp());

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'aadi@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(repo.signInCalls, ['aadi@example.com']);
  });

  testWidgets('repository failure renders the typed error message', (
    tester,
  ) async {
    repo.signInError = const AuthException(
      message: 'Those credentials didn\'t match an account.',
    );
    await tester.pumpWidget(buildApp());

    await tester.enterText(
      find.byKey(const Key('auth-email-field')),
      'aadi@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('auth-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(
      find.text('Those credentials didn\'t match an account.'),
      findsOneWidget,
    );
    // The submit button is re-enabled (not stuck submitting).
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const Key('auth-submit')))
          .onPressed,
      isNotNull,
    );
  });
}
