import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Force-directed graph layout (Obsidian-style) — pure Dart, no Flutter
/// dependencies beyond `dart:ui` geometry, so the physics is unit-testable.
///
/// Model (d3-force semantics):
///  - pairwise repulsion ~ k²/d (Coulomb),
///  - springs along edges toward [restLength],
///  - weak centering pull so the graph stays in view,
///  - velocity Verlet integration with velocity decay,
///  - alpha cools 1 → [alphaMin]; the simulation is [settled] at the floor.
///
/// Determinism: initial positions are placed on a golden-angle spiral and
/// all arithmetic is sequential — same input, same settled layout.
class ForceLayout {
  ForceLayout({
    required List<String> nodeIds,
    required List<(String, String)> edges,
    required this.bounds,
    double linkDistance = defaultLinkDistance,
  }) : restLength = linkDistance {
    final n = nodeIds.length;
    final center = Offset(bounds.width / 2, bounds.height / 2);
    final goldenAngle = math.pi * (3 - math.sqrt(5));
    final spread = linkDistance * 0.9;
    for (var i = 0; i < n; i++) {
      final r = n == 1 ? 0.0 : spread * math.sqrt(i + 0.5);
      final a = i * goldenAngle;
      _nodes.add(
        _SimNode(nodeIds[i], center + Offset(r * math.cos(a), r * math.sin(a))),
      );
    }
    final index = {
      for (final (i, id) in nodeIds.indexed) id: i,
    };
    for (final (from, to) in edges) {
      final a = index[from];
      final b = index[to];
      if (a == null || b == null || a == b) continue; // tolerate dangling ids
      _springs.add((a, b));
    }
  }

  static const double defaultLinkDistance = 130;

  /// Desired length of every spring (px).
  final double restLength;

  /// Viewport the layout settles inside (used for the centering force).
  final Size bounds;

  final List<_SimNode> _nodes = [];
  final List<(int, int)> _springs = [];

  double _alpha = 1.0;

  /// Current simulation energy (1 = freshly heated, → 0 = settled).
  double get alpha => _alpha;

  /// The simulation stops doing work once alpha bottoms out here.
  static const double alphaMin = 0.02;

  /// Fraction of alpha removed per tick (d3's alphaDecay ≈ 0.0228).
  static const double alphaDecay = 0.028;

  /// Fraction of velocity shed per tick (d3's velocityDecay).
  static const double velocityDecay = 0.85;

  /// Maximum displacement per tick — keeps a fresh graph from exploding.
  static const double maxSpeed = 26;

  bool get settled => _alpha < alphaMin;

  /// Re-heat after an interaction (drag, data change) so the graph
  /// re-settles smoothly around the perturbation.
  void reheat() => _alpha = math.max(_alpha, 0.5);

  Map<String, Offset> get positions => {
    for (final node in _nodes) node.id: node.position,
  };

  Offset positionOf(String id) =>
      _nodes.firstWhere((n) => n.id == id).position;

  /// Advance the simulation one tick. Returns true while still moving.
  bool tick() {
    if (settled) return false;
    final center = Offset(bounds.width / 2, bounds.height / 2);

    // Pairwise repulsion (O(n²) — fine for case-sized graphs; add
    // Barnes-Hut only if a room ever exceeds a few hundred entities).
    for (var i = 0; i < _nodes.length; i++) {
      for (var j = i + 1; j < _nodes.length; j++) {
        final a = _nodes[i];
        final b = _nodes[j];
        var delta = b.position - a.position;
        var d = delta.distance;
        if (d < 1e-3) {
          // Coincident nodes: push apart along a deterministic jitter.
          delta = Offset(0.37, 0.93);
          d = 1;
        }
        final strength = restLength * restLength / (d * d);
        final unit = delta / d;
        final f = (strength * _alpha).clamp(0.0, maxSpeed);
        a._accelerate(-unit * f);
        b._accelerate(unit * f);
      }
    }

    // Springs along edges.
    for (final (a, b) in _springs) {
      final na = _nodes[a];
      final nb = _nodes[b];
      final delta = nb.position - na.position;
      final d = delta.distance;
      if (d < 1e-3) continue;
      final f = (d - restLength) * 0.08 * _alpha;
      final unit = delta / d;
      na._accelerate(unit * f);
      nb._accelerate(-unit * f);
    }

    // Weak centering pull keeps the whole graph in view without hard
    // walls (walls produce visible pile-up artefacts).
    for (final node in _nodes) {
      if (!node.pinned) {
        node._accelerate((center - node.position) * 0.0025);
      }
    }

    // Integrate: velocity decay + positional update + alpha cooling.
    for (final node in _nodes) {
      node._integrate(velocityDecay, maxSpeed * _alpha);
    }
    // Decay BELOW the floor is what marks the sim settled — clamping
    // here would pin alpha at alphaMin forever.
    _alpha = math.max(0.0, _alpha * (1 - alphaDecay));
    return true;
  }

  /// Runs ticks until [ForceLayout.settled] or [maxTicks] — used by the
  /// reduced-motion path to render the final layout with no animation.
  void settle({int maxTicks = 400}) {
    for (var i = 0; i < maxTicks && tick(); i++) {}
  }

  // -- Drag support (used by the graph view's gesture handling) --------

  void beginDrag(String id, Offset at) {
    final node = _nodes.firstWhere((n) => n.id == id);
    node.pinned = true;
    node.position = at;
    node.velocity = Offset.zero;
    reheat();
  }

  void updateDrag(String id, Offset at) {
    final node = _nodes.firstWhere((n) => n.id == id);
    node.position = at;
    node.velocity = Offset.zero;
    reheat();
  }

  void endDrag(String id) {
    final node = _nodes.firstWhere((n) => n.id == id);
    node.pinned = false;
    reheat();
  }

  String? nodeAt(Offset point, double radius) {
    for (final node in _nodes) {
      if ((point - node.position).distance <= radius) return node.id;
    }
    return null;
  }
}

class _SimNode {
  _SimNode(this.id, this.position);

  final String id;
  Offset position;
  Offset velocity = Offset.zero;
  Offset force = Offset.zero;
  bool pinned = false;

  void _accelerate(Offset f) => force += f;

  void _integrate(double decay, double speedCap) {
    if (pinned) {
      force = Offset.zero;
      velocity = Offset.zero;
      return;
    }
    velocity = (velocity + force) * decay;
    force = Offset.zero;
    final speed = velocity.distance;
    if (speed > speedCap && speed > 0) {
      velocity = velocity / speed * speedCap;
    }
    position += velocity;
  }
}
