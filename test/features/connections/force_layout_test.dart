import 'dart:ui' show Offset, Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/connections/force_layout.dart';

ForceLayout _graph({
  int nodeCount = 5,
  List<(String, String)> edges = const [],
  Size bounds = const Size(800, 600),
}) {
  return ForceLayout(
    nodeIds: [for (var i = 0; i < nodeCount; i++) 'n$i'],
    edges: edges,
    bounds: bounds,
  );
}

void main() {
  group('ForceLayout — physics contract', () {
    test('settles: alpha reaches the floor and tick() reports still', () {
      final sim = _graph(
        nodeCount: 8,
        edges: [('n0', 'n1'), ('n1', 'n2'), ('n2', 'n3')],
      );
      sim.settle();

      expect(sim.settled, isTrue);
      expect(sim.tick(), isFalse); // no more work
      expect(sim.alpha, lessThan(ForceLayout.alphaMin));
    });

    test('all positions stay finite and non-negative-drift free (no NaN)', () {
      final sim = _graph(
        nodeCount: 12,
        edges: [('n0', 'n5'), ('n3', 'n7'), ('n9', 'n10')],
      );
      sim.settle();

      for (final p in sim.positions.values) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });

    test('springs work: connected nodes end closer than unconnected ones', () {
      final sim = _graph(
        nodeCount: 10,
        edges: [('n0', 'n1')],
        bounds: const Size(1000, 800),
      );
      sim.settle();

      final connected = (sim.positionOf('n0') - sim.positionOf('n1')).distance;
      final loose = (sim.positionOf('n2') - sim.positionOf('n8')).distance;
      // The spring pulls its pair well inside the rest length's
      // neighborhood; unrepelled-but-unlinked nodes settle far apart.
      expect(connected, lessThan(loose));
      expect(connected, lessThan(ForceLayout.defaultLinkDistance * 1.6));
    });

    test('repulsion works: nodes never collapse onto one point', () {
      final sim = _graph(
        nodeCount: 6,
        edges: [('n0', 'n1'), ('n1', 'n2'), ('n2', 'n3'), ('n3', 'n4')],
      );
      sim.settle();

      final positions = sim.positions.values.toList();
      for (var i = 0; i < positions.length; i++) {
        for (var j = i + 1; j < positions.length; j++) {
          expect(
            (positions[i] - positions[j]).distance,
            greaterThan(20),
            reason: 'nodes $i and $j collapsed onto each other',
          );
        }
      }
    });

    test('is deterministic: identical inputs → identical settled layout', () {
      final a = _graph(
        nodeCount: 7,
        edges: [('n0', 'n2'), ('n2', 'n4'), ('n1', 'n6')],
      )..settle();
      final b = _graph(
        nodeCount: 7,
        edges: [('n0', 'n2'), ('n2', 'n4'), ('n1', 'n6')],
      )..settle();

      for (final id in a.positions.keys) {
        expect(
          (a.positionOf(id) - b.positionOf(id)).distance,
          lessThan(0.001),
          reason: 'node $id settled at different spots',
        );
      }
    });

    test('single node settles at the canvas center', () {
      final sim = _graph(nodeCount: 1, bounds: const Size(800, 600));
      sim.settle();

      final p = sim.positionOf('n0');
      expect(p.dx, closeTo(400, 1));
      expect(p.dy, closeTo(300, 1));
    });

    test('drag pins the node at the pointer and survives further ticks', () {
      final sim = _graph(
        nodeCount: 5,
        edges: [('n0', 'n1'), ('n1', 'n2')],
      );
      const pinned = Offset(100, 100);
      sim.beginDrag('n0', pinned);
      sim.settle();

      expect(sim.positionOf('n0'), pinned);
      sim.endDrag('n0');
    });

    test('reheat restarts the simulation after settling', () {
      final sim = _graph(
        nodeCount: 5,
        edges: [('n0', 'n1')],
      )..settle();
      expect(sim.settled, isTrue);

      sim.reheat();
      expect(sim.settled, isFalse);
      expect(sim.tick(), isTrue);
    });

    test('nodeAt hit-tests within radius, prefers the nearest node', () {
      final sim = _graph(nodeCount: 2, edges: [('n0', 'n1')])..settle();
      final p0 = sim.positionOf('n0');

      expect(sim.nodeAt(p0, 26), 'n0');
      expect(sim.nodeAt(p0 + const Offset(500, 500), 26), isNull);
    });

    test('dangling edge ids are tolerated (no crash, no phantom spring)', () {
      final sim = ForceLayout(
        nodeIds: const ['a', 'b'],
        edges: const [('a', 'b'), ('a', 'ghost'), ('ghost', 'b')],
        bounds: const Size(400, 400),
      );
      sim.settle();

      expect(sim.positions.keys, hasLength(2));
      expect(sim.positions.values.every((p) => p.isFinite), isTrue);
    });

    test('settled layout stays inside a sane region of the bounds', () {
      // Centering force keeps the graph near the viewport; nothing may
      // fly off to infinity.
      final sim = _graph(
        nodeCount: 15,
        edges: [
          ('n0', 'n1'), ('n1', 'n2'), ('n2', 'n0'),
          ('n3', 'n4'), ('n5', 'n6'), ('n7', 'n8'),
          ('n9', 'n10'), ('n11', 'n12'), ('n13', 'n14'),
        ],
        bounds: const Size(800, 600),
      );
      sim.settle();

      final center = const Offset(400, 300);
      for (final p in sim.positions.values) {
        expect(
          (p - center).distance,
          lessThan(1600),
          reason: 'node drifted unreasonably far from the viewport',
        );
      }
    });
  });
}
