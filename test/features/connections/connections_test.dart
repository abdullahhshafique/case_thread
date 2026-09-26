import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/connections/connections_providers.dart';

void main() {
  group('EntityMapData', () {
    test('parses nodes and edges from the 0016 RPC shape', () {
      final data = EntityMapData.fromMap({
        'nodes': [
          {
            'id': 'n1',
            'type': 'person',
            'name': 'Suspect A',
            'attributes': {'note': 'x'},
          },
          {'id': 'n2', 'type': 'vehicle', 'name': 'Vehicle V01'},
        ],
        'edges': [
          {'id': 'e1', 'from': 'n1', 'to': 'n2', 'type': 'owns'},
        ],
      });

      expect(data.nodes.length, 2);
      expect(data.nodes[0].name, 'Suspect A');
      expect(data.nodes[0].attributes['note'], 'x');
      expect(data.edges.length, 1);
      expect(data.edges[0].fromId, 'n1');
      expect(data.edges[0].toId, 'n2');
      expect(data.edges[0].type, 'owns');
      expect(data.nodeById('n2')?.name, 'Vehicle V01');
      expect(data.nodeById('missing'), isNull);
    });

  group('SeedTemplate (0044 entity-seed import)', () {
    const map = {
      'id': 't1',
      'display_name': 'Robbery Starter',
      'description': 'Cast + scene for a street robbery',
      'entity_seed': {
        'entities': [
          {'key': 'suspect', 'entity_type': 'person', 'name': '{{suspect_name}}'},
          {'key': 'scene', 'entity_type': 'location', 'name': 'Dock 7 Warehouse'},
        ],
        'relationships': [
          {'from': 'suspect', 'to': 'scene', 'type': 'present_at'},
        ],
      },
    };

    test('parses entities/relationships and extracts placeholders', () {
      final t = SeedTemplate.fromMap(map);
      expect(t.displayName, 'Robbery Starter');
      expect(t.entities, hasLength(2));
      expect(t.relationships, hasLength(1));
      expect(t.placeholders, ['suspect_name']);
    });

    test('empty seed lists render as zero-count honest zeros', () {
      final t = SeedTemplate.fromMap({
        'id': 't2',
        'display_name': 'Empty',
        'entity_seed': {
          'entities': [],
          'relationships': [],
        },
      });
      expect(t.entities, isEmpty);
      expect(t.relationships, isEmpty);
      expect(t.placeholders, isEmpty);
    });
  });


    test('handles empty map payloads', () {
      final data = EntityMapData.fromMap({'nodes': [], 'edges': []});

      expect(data.nodes, isEmpty);
      expect(data.edges, isEmpty);
    });
  });
}
