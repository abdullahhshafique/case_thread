import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';
import 'package:case_thread/core/theme/app_theme.dart';
import 'package:case_thread/features/dashboard/case_briefing_card.dart';
import 'package:case_thread/features/rooms/room_permissions.dart';
import 'package:case_thread/features/rooms/rooms_providers.dart';

void main() {
  const roomId = 'room-1';

  CaseRoom room(String? briefing) => CaseRoom(
    id: roomId,
    name: 'Riverside Robbery #2291',
    caseType: 'legal',
    ownerId: 'u-1',
    status: 'active',
    investigationStatus: InvestigationStatus.underInvestigation,
    createdAt: DateTime(2026, 9, 10),
    briefing: briefing,
  );

  Widget app(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('shows briefing text when set', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomsProvider.overrideWith(() => _LoadedRooms(room('Suspect was seen at 21:55.'))),
        ],
        child: app(const CaseBriefingCard(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Suspect was seen at 21:55.'), findsOneWidget);
  });

  testWidgets('shows honest placeholder when unset', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomsProvider.overrideWith(() => _LoadedRooms(room(null))),
        ],
        child: app(const CaseBriefingCard(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No briefing yet.'), findsOneWidget);
  });

  testWidgets('edit affordance appears only for edit_case holders', (
    tester,
  ) async {
    Widget build(RoomPermissions permissions) => ProviderScope(
      overrides: [
        roomsProvider.overrideWith(() => _LoadedRooms(room(null))),
        myRoomPermissionsProvider(roomId).overrideWith((ref) => permissions),
      ],
      child: app(const CaseBriefingCard(roomId: roomId)),
    );

    await tester.pumpWidget(
      build(const RoomPermissions(permissions: {'edit_case': true})),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('briefing-edit')), findsOneWidget);

    // A second pumpWidget would UPDATE the existing ProviderScope in
    // place, and Riverpod does not re-apply changed overrides — tear the
    // tree down fully so the second scope is a fresh container.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      build(const RoomPermissions(permissions: {})),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('briefing-edit')), findsNothing);
  });
}

class _LoadedRooms extends RoomsController {
  _LoadedRooms(this.room);
  final CaseRoom room;

  @override
  RoomsState build() => RoomsLoaded([room]);
}
