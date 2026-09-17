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

    test('handles empty map payloads', () {
      final data = EntityMapData.fromMap({
        'nodes': [],
        'edges': [],
      });

      expect(data.nodes, isEmpty);
      expect(data.edges, isEmpty);
    });
  });
}
