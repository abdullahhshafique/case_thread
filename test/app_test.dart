import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/app.dart';
import 'package:case_thread/core/api/models.dart';
import 'package:case_thread/core/routing/app_router.dart';
import 'package:case_thread/features/auth/auth_providers.dart';
import 'package:case_thread/features/rooms/data/supabase_rooms_repository.dart';
import 'package:case_thread/features/rooms/domain/rooms_repository.dart';

import 'features/auth/fake_auth_repository.dart';

/// Fake rooms repo: static data, no network (Rules.md §7).
class FakeRoomsRepository implements RoomsRepository {
  @override
  Future<List<CaseRoom>> getMyRooms() async => const [];

  @override
  Future<CreatedRoom> createRoom({
    required String name,
    required String caseTypeId,
    String? accessCode,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<RoomPreview> previewRoomByCode(String code) async {
    throw UnimplementedError();
  }

  @override
  Future<JoinRequestResult> requestJoin(String code, String roleId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<RoomMember>> getMembers(String roomId) async => const [];

  @override
  Future<String> decideJoinRequest({
    required String roomId,
    required String memberId,
    required bool approve,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String> rotateCode(String roomId) async {
    throw UnimplementedError();
  }

  @override
  Future<InvestigationStatus> getInvestigationStatus(String roomId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> transitionInvestigationStatus({
    required String roomId,
    required InvestigationStatus newStatus,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CaseClosedSummary?> getClosedSummary(String roomId) async {
    throw UnimplementedError();
  }
}

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
        roomsRepositoryProvider.overrideWith((ref) => FakeRoomsRepository()),
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
    // Manual pumps, not pumpAndSettle: the console's ambient atmosphere
    // animates forever (by design), so settle would time out.
    await tester.pump(); // session emit + rooms load start
    await tester.pump(const Duration(milliseconds: 100)); // rooms loaded
    await tester.pump(const Duration(milliseconds: 100)); // rebuild settle

    expect(find.text('Cases'), findsOneWidget);
    expect(find.text('Open a case to start work'), findsOneWidget);
    expect(find.byKey(const Key('rooms-create')), findsOneWidget);
    expect(find.byKey(const Key('rooms-join')), findsOneWidget);
  });
}

const _testUser = AppUser(
  id: 'user-1',
  email: 'aadi@example.com',
  displayName: 'Aadi',
);
