import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';
import 'package:case_thread/features/alibis/alibi_providers.dart';
import 'package:case_thread/features/alibis/domain/alibi_repository.dart';
import 'package:case_thread/features/rooms/ai_suggestions.dart';
import 'package:case_thread/features/rooms/domain/evidence_repository.dart';
import 'package:case_thread/features/rooms/evidence_detail_sheet.dart';
import 'package:case_thread/features/rooms/room_permissions.dart';

void main() {
  const roomId = 'room-1';

  final entry = VaultEntry(
    id: 'ev-1',
    roomId: roomId,
    filename: 'cctv-still.png',
    storagePath: 'rooms/$roomId/cctv-still.png',
    version: 2,
    sizeBytes: 2048,
    mimeType: 'image/png',
    sha256: 'deadbeef123',
    uploadedAt: DateTime(2026, 9, 12),
    uploaderName: 'Alice',
    classification: 'fact',
  );

  Alibi alibi(String id, {AlibiStatus status = AlibiStatus.insufficientData}) =>
      Alibi(
        id: id,
        roomId: roomId,
        entityId: 'person-1',
        claimedWindowStart: DateTime(2026, 9, 10, 20),
        claimedWindowEnd: DateTime(2026, 9, 10, 23),
        claimText: 'I was at home',
        status: status,
        statusReason: '',
        createdAt: DateTime(2026, 9, 11),
      );

  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows metadata, classification and chain-of-custody hash', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRoomPermissionsProvider(roomId).overrideWith(
            (ref) => const RoomPermissions(
              permissions: {'approve_ai_findings': true},
            ),
          ),
          alibiListProvider(roomId).overrideWith((ref) => <Alibi>[]),
        ],
        child: app(EvidenceDetailSheet(roomId: roomId, entry: entry)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('cctv-still.png (v2)'), findsOneWidget);
    expect(find.text('Fact'), findsOneWidget);
    expect(find.text('deadbeef123'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Analyze this evidence'), findsOneWidget);
    // Empty alibi list renders the honest placeholder
    expect(find.text('No alibis waiting on verification.'), findsOneWidget);
  });

  testWidgets('without AI permission the analyze action is hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRoomPermissionsProvider(roomId).overrideWith(
            (ref) => const RoomPermissions(permissions: {}),
          ),
          alibiListProvider(roomId).overrideWith((ref) => <Alibi>[]),
        ],
        child: app(EvidenceDetailSheet(roomId: roomId, entry: entry)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Analyze this evidence'), findsNothing);
    expect(
      find.textContaining('AI-review permission'),
      findsOneWidget,
    );
  });

  testWidgets('run AI analysis calls the agent with the evidence id', (
    tester,
  ) async {
    final agentRepo = FakeAiAgentRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRoomPermissionsProvider(roomId).overrideWith(
            (ref) => const RoomPermissions(
              permissions: {'approve_ai_findings': true},
            ),
          ),
          alibiListProvider(roomId).overrideWith((ref) => <Alibi>[]),
          aiAgentRepositoryProvider.overrideWithValue(agentRepo),
        ],
        child: app(EvidenceDetailSheet(roomId: roomId, entry: entry)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('evidence-run-ai')));
    await tester.pumpAndSettle();

    expect(agentRepo.runCalls, hasLength(1));
    expect(agentRepo.runCalls.single.evidenceItemId, 'ev-1');
    expect(agentRepo.runCalls.single.roomId, roomId);
    expect(find.byKey(const Key('evidence-ai-result')), findsOneWidget);
  });

  testWidgets('verify alibi attaches the evidence id to the record', (
    tester,
  ) async {
    final alibiRepo = FakeAlibiRepository();
    final target = alibi('al-1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myRoomPermissionsProvider(roomId).overrideWith(
            (ref) => const RoomPermissions(permissions: {}),
          ),
          alibiListProvider(roomId).overrideWith((ref) => [target]),
          alibiRepositoryProvider.overrideWithValue(alibiRepo),
        ],
        child: app(EvidenceDetailSheet(roomId: roomId, entry: entry)),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Verified" on the alibi tile
    await tester.tap(find.text('Verified'));
    await tester.pumpAndSettle();

    // Reason dialog appears; confirm with a reason
    await tester.enterText(
      find.byKey(const Key('alibi-verify-reason')),
      'CCTV places them elsewhere',
    );
    await tester.tap(find.byKey(const Key('alibi-verify-confirm')));
    await tester.pumpAndSettle();

    expect(alibiRepo.verifyCalls, hasLength(1));
    expect(alibiRepo.verifyCalls.single.$1, 'al-1');
    expect(alibiRepo.verifyCalls.single.$2.status, AlibiStatus.verified);
    expect(
      alibiRepo.verifyCalls.single.$2.evidenceItemIds,
      ['ev-1'],
    );
    expect(alibiRepo.verifyCalls.single.$2.statusReason,
        'CCTV places them elsewhere');
  });
}

class FakeAiAgentRepository implements AiAgentRepository {
  final runCalls = <({String roomId, String agentId, String? evidenceItemId})>[];

  @override
  Future<List<AgentDefinition>> listAgents(String caseTypeId) async => const [
    AgentDefinition(
      id: 'agent-1',
      displayName: 'Evidence Analyst',
      description: 'Analyzes a single evidence item',
      caseType: null,
    ),
  ];

  @override
  Future<List<AiSuggestion>> listSuggestions(String roomId) async => const [];

  @override
  Stream<List<AiSuggestion>> watchSuggestions(String roomId) =>
      const Stream.empty();

  @override
  Future<String?> runAgent({
    required String roomId,
    required String agentId,
    String? evidenceItemId,
  }) async {
    runCalls.add((
      roomId: roomId,
      agentId: agentId,
      evidenceItemId: evidenceItemId,
    ));
    return 'sug-1';
  }

  @override
  Future<void> reviewSuggestion({
    required String suggestionId,
    required String decision,
    Map<String, dynamic>? editedOutput,
  }) async {}
}

class FakeAlibiRepository implements AlibiRepository {
  final verifyCalls = <(String, AlibiVerifyInput)>[];

  @override
  Future<List<Alibi>> list(String roomId) async => const [];

  @override
  Future<Alibi> create(String roomId, AlibiCreateInput input) =>
      throw UnimplementedError();

  @override
  Future<void> verify(String alibiId, AlibiVerifyInput input) async {
    verifyCalls.add((alibiId, input));
  }
}
