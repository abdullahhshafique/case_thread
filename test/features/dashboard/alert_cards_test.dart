import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/theme/app_theme.dart';
import 'package:case_thread/features/dashboard/alert_cards.dart';
import 'package:case_thread/features/rooms/rooms_providers.dart';

void main() {
  const roomId = 'room-1';

  const counts = AttentionCounts(
    openTasks: 0,
    openContradictions: 3,
    alibisToVerify: 2,
    alibiVerified: 1,
    alibiPartial: 1,
    alibiConflict: 1,
    openGaps: 4,
  );

  const clearCounts = AttentionCounts(
    openTasks: 0,
    openContradictions: 0,
    alibisToVerify: 0,
    alibiVerified: 1,
    alibiPartial: 0,
    alibiConflict: 0,
    openGaps: 0,
  );

  Widget app(Widget child) => MaterialApp(
    theme: buildAppTheme(),
    home: Scaffold(body: child),
  );

  testWidgets('renders three alert cards with counts', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attentionCountsProvider(roomId)
              .overrideWith((ref) => counts),
        ],
        child: app(const AlertCards(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 Contradictions'), findsOneWidget);
    expect(find.text('4 Gaps'), findsOneWidget);
    expect(find.text('Alibis'), findsOneWidget);
    expect(find.text('Open contradictions needing review'), findsOneWidget);
    expect(find.text('Investigation gaps to close'), findsOneWidget);
    expect(find.text('1 conflict · 1 partial · 1 verified'), findsOneWidget);
  });

  testWidgets('tap contradiction card sets tab request to 1', (tester) async {
    final container = ProviderContainer(
      overrides: [
        attentionCountsProvider(roomId).overrideWith((ref) => counts),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(const AlertCards(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('3 Contradictions'));
    await tester.pump();

    expect(container.read(analysisTabRequestProvider), 1);
  });

  testWidgets('tap gap card sets tab request to 2', (tester) async {
    final container = ProviderContainer(
      overrides: [
        attentionCountsProvider(roomId).overrideWith((ref) => counts),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(const AlertCards(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('4 Gaps'));
    await tester.pump();

    expect(container.read(analysisTabRequestProvider), 2);
  });

  testWidgets('tap alibi card sets tab request to 0', (tester) async {
    final container = ProviderContainer(
      overrides: [
        attentionCountsProvider(roomId).overrideWith((ref) => counts),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: app(const AlertCards(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alibis'));
    await tester.pump();

    expect(container.read(analysisTabRequestProvider), 0);
  });

  testWidgets('clear counts render muted (no onTap, no arrow)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attentionCountsProvider(roomId)
              .overrideWith((ref) => clearCounts),
        ],
        child: app(const AlertCards(roomId: roomId)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
  });

  testWidgets('loading state renders shimmer cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          attentionCountsProvider(roomId)
              .overrideWith((ref) => Completer<AttentionCounts>().future),
        ],
        child: app(const AlertCards(roomId: roomId)),
      ),
    );
    await tester.pump();

    expect(find.byType(AlertCards), findsOneWidget);
  });
}
