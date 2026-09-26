import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/connections/connections_providers.dart';
import 'package:case_thread/features/connections/entity_editor_sheet.dart';

void main() {
  const roomId = 'room-1';

  testWidgets('add entity sheet: name + type + note reach the repository', (
    tester,
  ) async {
    final repo = FakeConnectionsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: EntityEditorSheet(roomId: roomId)),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byKey(const Key('entity-name-field')), 'Imran Shaikh');
    await tester.tap(find.byKey(const Key('entity-type-location')));
    await tester.enterText(
      find.byKey(const Key('entity-note-field')),
      'warehouse security guard',
    );
    await tester.tap(find.byKey(const Key('entity-save')));
    await tester.pumpAndSettle();

    expect(repo.calls, hasLength(1));
    expect(repo.calls.single.entityType, 'location');
    expect(repo.calls.single.name, 'Imran Shaikh');
    expect(repo.calls.single.note, 'warehouse security guard');
  });

  testWidgets('save is disabled until a name is entered', (tester) async {
    final repo = FakeConnectionsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectionsRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: EntityEditorSheet(roomId: roomId)),
        ),
      ),
    );
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('entity-save')),
    );
    expect(button.onPressed, isNull);
    expect(repo.calls, isEmpty);
  });
}

class FakeConnectionsRepository implements ConnectionsRepository {
  final calls = <({String roomId, String entityType, String name, String? note})>[];

  @override
  Future<MapNode> addEntity({
    required String roomId,
    required String entityType,
    required String name,
    String? note,
  }) async {
    calls.add((
      roomId: roomId,
      entityType: entityType,
      name: name,
      note: note,
    ));
    return MapNode(id: 'new-1', type: entityType, name: name);
  }

  @override
  Future<EntityMapData> getMap(String roomId) async =>
      const EntityMapData(nodes: [], edges: []);

  @override
  Future<List<SeedTemplate>> listSeedTemplates() async => const [];

  @override
  Future<int> importEntitySeed({
    required String roomId,
    required String templateId,
    Map<String, String> values = const {},
  }) async =>
      0;

  @override
  Future<void> addRelationship({
    required String roomId,
    required String fromEntityId,
    required String toEntityId,
    required String relationshipType,
  }) async {}
}
