import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';
import 'package:case_thread/core/theme/app_theme.dart';
import 'package:case_thread/features/dashboard/dashboard_providers.dart';
import 'package:case_thread/features/dashboard/dashboard_screen.dart';
import 'package:case_thread/features/rooms/domain/evidence_repository.dart';
import 'package:case_thread/features/rooms/rooms_providers.dart';
import 'package:case_thread/features/rooms/vault_providers.dart';

/// Layout contract for the v3 Overview pane (Phase 6). Pumps the real
/// widget through a full layout pass with every provider overridden —
/// this is the test class that would have caught both field bugs from
/// 2026-09-20: the events-chart FractionallySizedBox getting unbounded
/// height, and the avatar stack's negative Container margin assertion.
void main() {
  const roomId = 'room-1';

  final room = CaseRoom(
    id: roomId,
    name: 'Riverside Robbery #2291',
    caseType: 'legal',
    ownerId: 'u-1',
    status: 'active',
    investigationStatus: InvestigationStatus.underInvestigation,
    createdAt: DateTime(2026, 9, 10),
  );

  final members = [
    RoomMember(
      id: 'm-1',
      roomId: roomId,
      userId: 'u-1',
      roleId: 'lead_investigator',
      status: MemberStatus.approved,
      requestedAt: DateTime(2026, 9, 10),
      displayName: 'A',
    ),
    RoomMember(
      id: 'm-2',
      roomId: roomId,
      userId: 'u-2',
      roleId: 'analyst',
      status: MemberStatus.approved,
      requestedAt: DateTime(2026, 9, 10),
      displayName: null, // exercises the '?' initials fallback
    ),
  ];

  VaultEntry entry(int n, {String? classification}) => VaultEntry(
    id: 'e-$n',
    roomId: roomId,
    filename: 'evidence-$n.pdf',
    storagePath: 'rooms/$roomId/evidence-$n.pdf',
    version: 1,
    sizeBytes: 1000 + n,
    mimeType: 'application/pdf',
    sha256: 'hash-$n',
    uploadedAt: DateTime(2026, 9, 12),
    classification: classification,
  );

  // Riverpod 3.4.3 does not export the `Override` type name, so each
  // test builds its own ProviderScope (the list literal infers the
  // element type) around this shared app wrapper.
  Widget app(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('populated overview lays out without exceptions', (tester) async {
    // Tall viewport: the alert cards/donut sit far down a lazy ListView
    // and would never be built at the default 600x800 test size.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardStatsProvider(roomId).overrideWith(
            (ref) => const CaseStatistics(
              roomId: roomId,
              evidenceCount: 5,
              peopleCount: 4,
              locationsCount: 4,
              eventsCount: 7,
              contradictionsCount: 1,
              gapsCount: 2,
              unverifiedAlibisCount: 1,
              aiFindingsCount: 0,
            ),
          ),
          dashboardBreakdownProvider(roomId).overrideWith(
            (ref) => const CaseBreakdown(
              evidenceByType: {'pdf': 3, 'image': 1, 'other': 1},
              eventsPerDay: {'2026-09-10': 4, '2026-09-11': 2},
            ),
          ),
          vaultProvider(roomId).overrideWith(
            (ref) => VaultLoaded([
              entry(1, classification: 'fact'),
              entry(2, classification: 'fact'),
              entry(3, classification: 'claim'),
              entry(4, classification: 'fact'),
              entry(5), // unclassified → coverage 4/5 = 80%
            ]),
          ),
          roomMembersProvider(roomId).overrideWith((ref) => members),
          roomsProvider.overrideWith(() => _LoadedRooms(room)),
          attentionCountsProvider(roomId).overrideWith(
            (ref) => const AttentionCounts(
              openTasks: 1,
              openContradictions: 2,
              alibisToVerify: 1,
              alibiVerified: 3,
              alibiPartial: 1,
              alibiConflict: 1,
              openGaps: 2,
            ),
          ),
        ],
        child: app(const DashboardScreen(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    // The whole point: no layout assertion, no RangeError, no overflow.
    expect(tester.takeException(), isNull);
    expect(find.text('Riverside Robbery #2291'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget); // coverage meter
    expect(find.text('2 investigators in this room'), findsOneWidget);
    // Phase 2 widgets rendered
    expect(find.textContaining('No briefing yet'), findsOneWidget);
    expect(find.text('2 Contradictions'), findsOneWidget);
    expect(find.text('2 Gaps'), findsOneWidget);
    expect(find.text('Alibis'), findsOneWidget);
  });

  testWidgets('empty overview (fresh case) lays out without exceptions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardStatsProvider(roomId).overrideWith(
            (ref) => const CaseStatistics(
              roomId: roomId,
              evidenceCount: 0,
              peopleCount: 0,
              locationsCount: 0,
              eventsCount: 0,
              contradictionsCount: 0,
              gapsCount: 0,
              unverifiedAlibisCount: 0,
              aiFindingsCount: 0,
            ),
          ),
          dashboardBreakdownProvider(roomId).overrideWith(
            (ref) => const CaseBreakdown(evidenceByType: {}, eventsPerDay: {}),
          ),
          vaultProvider(roomId).overrideWith((ref) => VaultLoaded(const [])),
          roomMembersProvider(roomId).overrideWith((ref) => const []),
          roomsProvider.overrideWith(() => _LoadedRooms(room)),
          attentionCountsProvider(roomId).overrideWith(
            (ref) => const AttentionCounts(
              openTasks: 0,
              openContradictions: 0,
              alibisToVerify: 0,
              alibiVerified: 0,
              alibiPartial: 0,
              alibiConflict: 0,
              openGaps: 0,
            ),
          ),
        ],
        child: app(const DashboardScreen(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('0%'), findsOneWidget); // empty coverage renders 0
    expect(find.text('0 investigators in this room'), findsOneWidget);
    // Phase 2: empty counts → alert cards render muted (all three still
    // visible, honest zeros), donut hidden (no alibis at all)
    expect(find.text('Alibis'), findsOneWidget);
  });
}

/// Stub rooms controller — the pane only reads the room row.
class _LoadedRooms extends RoomsController {
  _LoadedRooms(this.room);
  final CaseRoom room;

  @override
  RoomsState build() => RoomsLoaded([room]);
}
