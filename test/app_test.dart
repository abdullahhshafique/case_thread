import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/app.dart';
import 'package:case_thread/core/routing/app_router.dart';
import 'package:case_thread/features/auth/auth_providers.dart';

import 'features/auth/fake_auth_repository.dart';

/// Whole-app smoke tests: bootstrap states and routing guards
/// (ExecutionPlan.md Sprint 1 — unauthenticated → auth screen).
void main() {
  late FakeAuthRepository repo;

  setUp(() {
    repo = FakeAuthRepository();
  });

  Widget buildConfiguredApp() {
    return ProviderScope(
      overrides: [
        appConfiguredProvider.overrideWith((ref) => true),
        authRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: const CaseThreadApp(),
    );
  }

  testWidgets('unconfigured app shows the setup screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CaseThreadApp()));
    await tester.pumpAndSettle();

    expect(find.text('CaseThread'), findsOneWidget);
    expect(
      find.textContaining('isn\'t connected to a backend'),
      findsOneWidget,
    );
  });

  testWidgets('configured + signed out → auth screen', (tester) async {
    await tester.pumpWidget(buildConfiguredApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-email-field')), findsOneWidget);
  });

  testWidgets('configured + signed in → rooms screen', (tester) async {
    await tester.pumpWidget(buildConfiguredApp());
    // Emit a signed-in user before the first settle so the redirect sees it.
    unawaited(
      Future<void>.delayed(Duration.zero).then((_) => repo.emit(_testUser)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your case rooms'), findsOneWidget);
    expect(find.text('No case rooms yet'), findsOneWidget);
    expect(find.text('Aadi'), findsOneWidget);
  });
}

const _testUser = AppUser(
  id: 'user-1',
  email: 'aadi@example.com',
  displayName: 'Aadi',
);
