import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Permission;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/room_permissions.dart';
import 'connections_providers.dart';

/// Connections map (Phase 6, doc §13): interactive entity graph.
/// Nodes colored by type, edges labeled; tap a node or edge for the
/// "Why are these connected?" detail sheet.
class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(entityMapProvider(roomId));
    final canEdit = ref
        .watch(myRoomPermissionsProvider(roomId))
        .maybeWhen(
          data: (p) => p.can(Permission.editCase),
          orElse: () => false,
        );
    final text = Theme.of(context).textTheme;

    return map.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text('$error', style: text.bodyMedium),
        ),
      ),
      data: (data) {
        if (data.nodes.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.hub_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('No entities yet', style: text.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Add people, locations and vehicles to see how the '
                  'case connects.',
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return Stack(
          children: [
            Positioned.fill(
              child: _GraphView(
                data: data,
                onNodeTap: (node) => _showNodeSheet(context, data, node),
                onEdgeTap: (edge) => _showEdgeSheet(context, data, edge),
              ),
            ),
            if (canEdit)
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: FloatingActionButton.small(
                  key: const Key('map-add-relationship'),
                  tooltip: 'Add relationship',
                  onPressed: () => _addRelationship(context, ref, data),
                  child: const Icon(Icons.add),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Node detail: identity + every direct connection with the
  /// relationship label — the "why connected" answer (doc §13).
  void _showNodeSheet(BuildContext context, EntityMapData data, MapNode node) {
    final edges = data.edges
        .where((e) => e.fromId == node.id || e.toId == node.id)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                _nodeIcon(node.type),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    node.name,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Connected to',
              style: Theme.of(sheetContext).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (edges.isEmpty)
              Text(
                'No direct connections yet.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
            for (final e in edges)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: _nodeIcon(
                  data
                          .nodeById(e.fromId == node.id ? e.toId : e.fromId)
                          ?.type ??
                      'person',
                ),
                title: Text(
                  data
                          .nodeById(e.fromId == node.id ? e.toId : e.fromId)
                          ?.name ??
                      'Unknown',
                ),
                subtitle: Text(e.type.replaceAll('_', ' ')),
              ),
          ],
        ),
      ),
    );
  }

  /// Edge detail: both endpoints + relationship type + supporting
  /// linked analysis (alibis/contradictions) where present.
  void _showEdgeSheet(BuildContext context, EntityMapData data, MapEdge edge) {
    final from = data.nodeById(edge.fromId);
    final to = data.nodeById(edge.toId);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why connected?',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      from?.name ?? '?',
                      style: Theme.of(sheetContext).textTheme.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      to?.name ?? '?',
                      style: Theme.of(sheetContext).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Chip(
                label: Text(edge.type.replaceAll('_', ' ')),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This relationship was recorded by the investigation '
                'team. Check the linked evidence and timeline events for '
                'the supporting record.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addRelationship(
    BuildContext context,
    WidgetRef ref,
    EntityMapData data,
  ) async {
    if (data.nodes.length < 2) return;
    String? fromId;
    String? toId;
    final controller = TextEditingController();
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add relationship',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                key: const Key('map-from-select'),
                decoration: const InputDecoration(labelText: 'From entity'),
                items: [
                  for (final n in data.nodes)
                    DropdownMenuItem(value: n.id, child: Text(n.name)),
                ],
                onChanged: (v) => setSheetState(() => fromId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                key: const Key('map-to-select'),
                decoration: const InputDecoration(labelText: 'To entity'),
                items: [
                  for (final n in data.nodes)
                    DropdownMenuItem(value: n.id, child: Text(n.name)),
                ],
                onChanged: (v) => setSheetState(() => toId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                key: const Key('map-type-field'),
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Relationship type',
                  hintText: 'e.g. owns, witnessed, spotted_at',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('map-save-relationship'),
                  onPressed: (fromId == null || toId == null)
                      ? null
                      : () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final from = fromId;
    final to = toId;
    if (saved != true || from == null || to == null) return;
    final type = controller.text.trim();
    if (type.isEmpty) return;
    try {
      await ref
          .read(connectionsRepositoryProvider)
          .addRelationship(
            roomId: roomId,
            fromEntityId: from,
            toEntityId: to,
            relationshipType: type,
          );
      ref.invalidate(entityMapProvider(roomId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  static Icon _nodeIcon(String type) {
    return switch (type) {
      'person' => const Icon(Icons.person_outline),
      'location' => const Icon(Icons.location_on_outlined),
      'vehicle' => const Icon(Icons.directions_car_outlined),
      'evidence' => const Icon(Icons.description_outlined),
      'org' => const Icon(Icons.business_outlined),
      _ => const Icon(Icons.circle_outlined),
    };
  }
}

/// Animated v3-style graph (v3 §9 connections): nodes as pulsing orbs,
/// edges as flowing dashed lines, legend pill at the bottom. Circular
/// layout + tap hit-testing preserved; deterministic and readable for
/// case-sized graphs (< ~40 nodes). Reduced-motion renders it static.
class _GraphView extends StatefulWidget {
  const _GraphView({
    required this.data,
    required this.onNodeTap,
    required this.onEdgeTap,
  });

  final EntityMapData data;
  final void Function(MapNode) onNodeTap;
  final void Function(MapEdge) onEdgeTap;

  @override
  State<_GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<_GraphView>
    with SingleTickerProviderStateMixin {
  static const double _nodeRadius = 26;

  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final positions = _layout(size);
        final legendTypes = _legendTypes();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition, positions),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  size: size,
                  painter: _GraphPainter(
                    data: widget.data,
                    positions: positions,
                    nodeRadius: _nodeRadius,
                    t: reduceMotion ? 0 : _flow.value,
                  ),
                ),
              ),
              if (legendTypes.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(child: _Legend(types: legendTypes)),
                ),
            ],
          ),
        );
      },
    );
  }

  Map<String, Offset> _layout(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radiusX = math.max(0.0, size.width / 2 - _nodeRadius * 2);
    final radiusY = math.max(0.0, size.height / 2 - _nodeRadius * 2);
    final n = widget.data.nodes.length;
    final out = <String, Offset>{};
    for (var i = 0; i < n; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / n);
      out[widget.data.nodes[i].id] = n == 1
          ? center
          : center +
                Offset(radiusX * math.cos(angle), radiusY * math.sin(angle));
    }
    return out;
  }

  void _handleTap(Offset tap, Map<String, Offset> positions) {
    // Nodes first (closer targets win).
    for (final node in widget.data.nodes) {
      final p = positions[node.id];
      if (p != null && (tap - p).distance <= _nodeRadius) {
        widget.onNodeTap(node);
        return;
      }
    }
    // Then edges: distance to the segment < 12px.
    for (final edge in widget.data.edges) {
      final a = positions[edge.fromId];
      final b = positions[edge.toId];
      if (a == null || b == null) continue;
      if (_distanceToSegment(tap, a, b) <= 12) {
        widget.onEdgeTap(edge);
        return;
      }
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final denom = ab.distanceSquared;
    final t = denom == 0
        ? 0.0
        : ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / denom;
    final clamped = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * clamped, a.dy + ab.dy * clamped);
    return (p - proj).distance;
  }

  /// Legend entries for the types actually present, in stable order.
  List<(String, Color)> _legendTypes() {
    const order = [
      ('person', 'Person'),
      ('location', 'Location'),
      ('vehicle', 'Vehicle'),
      ('evidence', 'Evidence'),
      ('org', 'Org'),
    ];
    final present = widget.data.nodes.map((n) => n.type).toSet();
    final out = <(String, Color)>[
      for (final (type, label) in order)
        if (present.contains(type)) (label, _GraphPainter.nodeColor(type)),
    ];
    if (present.where((t) => !order.any((o) => o.$1 == t)).isNotEmpty) {
      out.add(('Other', _GraphPainter.nodeColor('other')));
    }
    return out;
  }
}

/// Bottom legend pill (v3 §9 .legend): colored dot + label per type.
class _Legend extends StatelessWidget {
  const _Legend({required this.types});

  final List<(String, Color)> types;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.consoleBorder),
        color: const Color(0xE60B0D14),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (label, color) in types)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.consoleMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.data,
    required this.positions,
    required this.nodeRadius,
    required this.t,
  });

  final EntityMapData data;
  final Map<String, Offset> positions;
  final double nodeRadius;

  /// Animation phase 0..1 — drives edge dash flow + node pulse.
  final double t;

  static Color nodeColor(String type) => switch (type) {
    'person' => AppColors.statusOpen,
    'location' => AppColors.stateSuccess,
    'vehicle' => AppColors.statePending,
    'evidence' => AppColors.statusGap,
    'org' => AppColors.statusNeutral,
    _ => AppColors.statusNeutral,
  };

  static const _knownTypes = {
    'person',
    'location',
    'vehicle',
    'evidence',
    'org',
  };

  @override
  void paint(Canvas canvas, Size size) {
    // -- Edges: flowing dashes (under nodes) --------------------------
    final edgePaint = Paint()
      ..color = const Color(0x4D8180F8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const period = 11.0; // dash + gap
    final flow = -t * period;

    for (final edge in data.edges) {
      final a = positions[edge.fromId];
      final b = positions[edge.toId];
      if (a == null || b == null) continue;
      final delta = b - a;
      final len = delta.distance;
      if (len == 0) continue;
      final unit = delta / len;
      for (var d = flow; d < len; d += period) {
        final s = d.clamp(0.0, len);
        final e = (d + dash).clamp(0.0, len);
        if (e > s) {
          canvas.drawLine(a + unit * s, a + unit * e, edgePaint);
        }
      }
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      _drawLabel(
        canvas,
        edge.type.replaceAll('_', ' '),
        mid,
        AppColors.textSecondary.withValues(alpha: 0.75),
        fontSize: 9.5,
      );
    }

    // -- Nodes: orbs with pulse ring + glowing core --------------------
    for (final node in data.nodes) {
      final p = positions[node.id];
      if (p == null) continue;
      final color = nodeColor(node.type);
      final unknown = !_knownTypes.contains(node.type);

      // Pulse ring (known types only — unknown is dashed, quiet).
      if (!unknown) {
        canvas.drawCircle(
          p,
          nodeRadius * (1.0 + 0.55 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color.withValues(alpha: (1 - t) * 0.45),
        );
      }

      // Dark disc body.
      canvas.drawCircle(
        p,
        nodeRadius,
        Paint()..color = const Color(0xE60B0D14),
      );

      // Ring — solid for known types, dashed for unknown.
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color;
      if (unknown) {
        final circle = Path()
          ..addOval(Rect.fromCircle(center: p, radius: nodeRadius));
        for (final metric in circle.computeMetrics()) {
          for (var d = 0.0; d < metric.length; d += 8) {
            canvas.drawPath(
              metric.extractPath(d, (d + 4).clamp(0.0, metric.length)),
              ringPaint,
            );
          }
        }
      } else {
        canvas.drawCircle(p, nodeRadius, ringPaint);
      }

      // Glowing core dot.
      canvas.drawCircle(
        p,
        5,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(p, 5, Paint()..color = color);

      _drawLabel(
        canvas,
        node.name,
        p + Offset(0, nodeRadius + 10),
        AppColors.consoleText,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    double fontSize = 10.5,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 120);
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height));
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.t != t;
}
