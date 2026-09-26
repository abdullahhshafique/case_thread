import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Permission;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/room_permissions.dart';
import 'connections_providers.dart';
import 'entity_editor_sheet.dart';
import 'entity_import_sheet.dart';
import 'force_layout.dart';

/// Connections map (Phase 6, doc §13): interactive entity graph.
/// Obsidian-style force-directed layout (Phases.md §13) with a
/// zoom/pan camera, hover highlight, type filters, local-graph focus
/// mode, search-jump, and template-driven entity import. Tap a node or
/// edge for the "Why are these connected?" detail sheet.
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      key: const Key('map-add-entity'),
                      tooltip: 'Add entity',
                      heroTag: 'map-add-entity',
                      onPressed: () =>
                          EntityEditorSheet.show(context, roomId),
                      child: const Icon(Icons.person_add_alt),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FloatingActionButton.small(
                      key: const Key('map-import-seed'),
                      tooltip: 'Import entity template',
                      heroTag: 'map-import-seed',
                      onPressed: () =>
                          EntityImportSheet.show(context, roomId),
                      child: const Icon(Icons.playlist_add),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FloatingActionButton.small(
                      key: const Key('map-add-relationship'),
                      tooltip: 'Add relationship',
                      heroTag: 'map-add-relationship',
                      onPressed: () => _addRelationship(context, ref, data),
                      child: const Icon(Icons.add),
                    ),
                  ],
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

// ═══════════════════════════════════════════════════════════
//  GRAPH VIEW (force-directed, Phases.md §13)
// ═══════════════════════════════════════════════════════════════

/// Obsidian-style force-directed graph: nodes settle via a physics
/// simulation (repulsion + springs + centering, alpha-cooled), dragging
/// a node re-heats the layout, the camera supports focal-anchored zoom
/// and pan, hovering dims everything but the 1-hop neighborhood.
/// Deterministic for a given (data, size). Reduced-motion renders the
/// fully settled layout with no animation.
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

class _GraphViewState extends State<_GraphView> with TickerProviderStateMixin {
  static const double nodeRadius = 26;

  /// Dash-flow + pulse phase (cosmetic; independent of the simulation).
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  /// Physics ticker — runs only while the layout is unsettled.
  late final Ticker _simTicker = createTicker(_onSimTick);

  ForceLayout? _sim;
  Size? _simSize;
  EntityMapData? _simData; // which dataset the sim was built for
  bool _reduceMotion = false;
  String? _draggingId;

  // Camera (zoom/pan; the painter draws through it).
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  double _lastScale = 1.0; // cumulative scale of the in-flight gesture
  Offset? _lastFocal;

  // Hover highlight: hovered node + its 1-hop neighborhood stay bright,
  // everything else dims (null = no dimming).
  String? _hoverId;
  Set<String>? _highlight;

  // Filters, local-graph focus mode, search-jump.
  final Set<String> _hiddenTypes = {};
  final Set<String> _hiddenRelTypes = {};
  bool _showFilters = false;
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  bool _focusMode = false;
  String? _focusId;
  int _focusDepth = 1;
  Timer? _flashTimer;

  EntityMapData? _visibleCache;
  String _visibleKey = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  Offset _toGraph(Offset screen) => (screen - _pan) / _zoom;

  @override
  void didUpdateWidget(covariant _GraphView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      // A focus node that vanished with the new data clears itself.
      _visibleCache = null;
      if (_focusId != null && _visible.nodeById(_focusId!) == null) {
        _focusId = null;
      }
      _rebuildSimulation(_simSize, _visible);
      if (_reduceMotion) setState(() {}); // no ticker to repaint for us
    }
  }

  @override
  void dispose() {
    _simTicker.dispose();
    _flow.dispose();
    _searchController.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  // -- Derived "visible" dataset: type filters → focus subgraph --------

  /// Memoized subgraph after entity-type and relationship-type filters
  /// and (when active) the local-graph depth window. Identity-stable, so
  /// the simulation only rebuilds when the selection actually changes.
  EntityMapData get _visible {
    final key = '${identityHashCode(widget.data)}|'
        '${_hiddenTypes.join(',')}|${_hiddenRelTypes.join(',')}|'
        '$_focusMode|$_focusId|$_focusDepth';
    if (_visibleCache != null && key == _visibleKey) return _visibleCache!;

    final nodes = widget.data.nodes
        .where((n) => !_hiddenTypes.contains(n.type))
        .toList(growable: false);
    final nodeIds = nodes.map((n) => n.id).toSet();
    final edges = widget.data.edges
        .where(
          (e) =>
              !_hiddenRelTypes.contains(e.type) &&
              nodeIds.contains(e.fromId) &&
              nodeIds.contains(e.toId),
        )
        .toList(growable: false);

    var out = EntityMapData(nodes: nodes, edges: edges);

    // Local-graph mode: only the focus node within [_focusDepth] hops.
    if (_focusMode && _focusId != null && nodeIds.contains(_focusId)) {
      final keep = <String>{_focusId!};
      var frontier = <String>{_focusId!};
      for (var d = 0; d < _focusDepth; d++) {
        final next = <String>{};
        for (final e in edges) {
          if (frontier.contains(e.fromId) && !keep.contains(e.toId)) {
            next.add(e.toId);
          }
          if (frontier.contains(e.toId) && !keep.contains(e.fromId)) {
            next.add(e.fromId);
          }
        }
        keep.addAll(next);
        frontier = next;
      }
      out = EntityMapData(
        nodes: nodes.where((n) => keep.contains(n.id)).toList(),
        edges: edges
            .where((e) => keep.contains(e.fromId) && keep.contains(e.toId))
            .toList(),
      );
    }

    _visibleCache = out;
    _visibleKey = key;
    return out;
  }

  // -- Simulation lifecycle ---------------------------------------------

  /// Safe to call from [build] (no setState — the ticker's first tick
  /// repaints) and from [didUpdateWidget].
  void _rebuildSimulation(Size? size, EntityMapData data) {
    _simSize = size;
    _simData = data;
    if (size == null || data.nodes.isEmpty) {
      _sim = null;
      _simTicker.stop();
      return;
    }
    _sim = ForceLayout(
      nodeIds: [for (final n in data.nodes) n.id],
      edges: [for (final e in data.edges) (e.fromId, e.toId)],
      bounds: size,
    );
    if (_reduceMotion) {
      // No animation allowed: jump straight to the settled layout.
      _sim!.settle();
      _simTicker.stop();
    } else {
      _simTicker
        ..stop()
        ..start();
    }
  }

  void _onSimTick(Duration elapsed) {
    final sim = _sim;
    if (sim == null) {
      _simTicker.stop();
      return;
    }
    // Two sub-steps per frame: settles ~2x faster without looking rushed.
    final moving = sim.tick() | sim.tick();
    if (!moving) _simTicker.stop();
    setState(() {}); // repaint with the new positions
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final visible = _visible;
        if (_sim == null ||
            _simSize != size ||
            !identical(_simData, visible)) {
          _rebuildSimulation(size, visible);
        }
        final sim = _sim;
        final positions = sim?.positions ??
            <String, Offset>{
              for (final n in visible.nodes)
                n.id: Offset(size.width / 2, size.height / 2),
            };
        final legendTypes = _legendTypes(visible);
        return MouseRegion(
          onHover: (event) => _handleHover(event.localPosition),
          onExit: (_) => _handleHoverEnd(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => _handleTap(_toGraph(details.localPosition)),
            // onScale* covers BOTH one-finger pan and pinch-zoom, so node
            // drag, canvas pan and zoom share one gesture arena cleanly.
            onScaleStart: _handleScaleStart,
            onScaleUpdate: _handleScaleUpdate,
            onScaleEnd: (_) => _handleScaleEnd(),
            child: Stack(
              children: [
                Positioned.fill(
                  // Isolate the 60fps graph painter from the rest of the
                  // tree — without this every animation tick repaints the
                  // whole pane stack.
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: size,
                      painter: _GraphPainter(
                        data: visible,
                        positions: positions,
                        nodeRadius: nodeRadius,
                        t: _reduceMotion ? 0 : _flow.value,
                        zoom: _zoom,
                        pan: _pan,
                        highlight: _highlight,
                      ),
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
                // -- Top-right controls: search / filters / focus --------
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GraphPill(
                            key: const Key('graph-search-toggle'),
                            icon: Icons.search,
                            tooltip: 'Find entity',
                            active: _showSearch,
                            onTap: () => setState(() {
                              _showSearch = !_showSearch;
                              if (!_showSearch) _searchController.clear();
                            }),
                          ),
                          const SizedBox(width: 6),
                          _GraphPill(
                            key: const Key('graph-filter-toggle'),
                            icon: Icons.filter_list,
                            tooltip: 'Filter types',
                            active: _showFilters,
                            onTap: () =>
                                setState(() => _showFilters = !_showFilters),
                          ),
                          const SizedBox(width: 6),
                          _GraphPill(
                            key: const Key('graph-focus-toggle'),
                            icon: Icons.center_focus_strong,
                            tooltip: 'Local graph (depth window)',
                            active: _focusMode,
                            onTap: () => setState(() {
                              _focusMode = !_focusMode;
                              if (!_focusMode) _focusId = null;
                            }),
                          ),
                        ],
                      ),
                      if (_showSearch)
                        _SearchOverlay(
                          controller: _searchController,
                          nodes: visible.nodes,
                          onPick: _jumpTo,
                          onClose: () => setState(() {
                            _showSearch = false;
                            _searchController.clear();
                          }),
                        ),
                      if (_showFilters)
                        _FilterPanel(
                          nodes: visible.nodes,
                          edges: visible.edges,
                          hiddenTypes: _hiddenTypes,
                          hiddenRelTypes: _hiddenRelTypes,
                          onChanged: () {
                            setState(() {
                              if (_focusId != null &&
                                  _visible.nodeById(_focusId!) == null) {
                                _focusId = null;
                              }
                            });
                          },
                        ),
                      if (_focusMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _FocusBar(
                            depth: _focusDepth,
                            focused: _focusId != null,
                            onDepth: (d) =>
                                setState(() => _focusDepth = d),
                            onClear: () => setState(() => _focusId = null),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset graphPoint) {
    final positions = _sim?.positions ?? const <String, Offset>{};
    final visible = _visible;
    // Nodes first (closer targets win).
    for (final node in visible.nodes) {
      final p = positions[node.id];
      if (p != null && (graphPoint - p).distance <= nodeRadius) {
        if (_focusMode) {
          // Local-graph mode: tap re-focuses instead of opening the sheet.
          setState(() => _focusId = node.id);
          return;
        }
        widget.onNodeTap(node);
        return;
      }
    }
    if (_focusMode) return; // edges don't refocus
    // Then edges: distance to the segment < 12px (graph space).
    for (final edge in visible.edges) {
      final a = positions[edge.fromId];
      final b = positions[edge.toId];
      if (a == null || b == null) continue;
      if (_distanceToSegment(graphPoint, a, b) <= 12) {
        widget.onEdgeTap(edge);
        return;
      }
    }
  }

  // -- Search-jump -------------------------------------------------------

  /// Centers the camera on [node], zooms in a touch and flashes its
  /// neighborhood for a moment.
  void _jumpTo(MapNode node) {
    final size = _simSize;
    final sim = _sim;
    if (size == null || sim == null) return;
    final pos = sim.positionOf(node.id);
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _zoom = 1.4;
      _pan = Offset(size.width / 2, size.height / 2) - pos * _zoom;
      _highlight = _neighborhood(node.id);
    });
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  // -- Hover highlight ---------------------------------------------------

  void _handleHover(Offset screen) {
    final sim = _sim;
    if (sim == null) return;
    final id = sim.nodeAt(_toGraph(screen), nodeRadius);
    if (id == _hoverId) return;
    setState(() {
      _hoverId = id;
      _highlight = id == null ? null : _neighborhood(id);
    });
  }

  void _handleHoverEnd() {
    if (_hoverId == null) return;
    setState(() {
      _hoverId = null;
      _highlight = null;
    });
  }

  /// Node + everything directly linked to it (within the visible set).
  Set<String> _neighborhood(String id) {
    final out = <String>{id};
    for (final e in _visible.edges) {
      if (e.fromId == id) out.add(e.toId);
      if (e.toId == id) out.add(e.fromId);
    }
    return out;
  }

  // -- Camera (pan + pinch zoom) + node drag ----------------------------

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0; // ScaleUpdateDetails.scale is cumulative per gesture
    _lastFocal = details.localFocalPoint;
    // A single-pointer drag that starts on a node grabs the node; on
    // empty space it pans the camera.
    if (details.pointerCount == 1) {
      final sim = _sim;
      final id = sim?.nodeAt(_toGraph(details.localFocalPoint), nodeRadius);
      if (sim != null && id != null) {
        _draggingId = id;
        sim.beginDrag(id, _toGraph(details.localFocalPoint));
      }
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final dragging = _draggingId;
    if (dragging != null) {
      _sim?.updateDrag(dragging, _toGraph(details.localFocalPoint));
      return;
    }
    // Pinch: zoom around the focal point so what's under the fingers
    // stays under the fingers; pan rides the focal movement.
    final focal = details.localFocalPoint;
    final newZoom = (_zoom * details.scale / _lastScale).clamp(0.4, 3.0);
    final graphAtFocal = (focal - _pan) / _zoom;
    setState(() {
      _zoom = newZoom;
      _pan = focal - graphAtFocal * _zoom;
      _pan += focal - (_lastFocal ?? focal);
    });
    _lastScale = details.scale;
    _lastFocal = focal;
  }

  void _handleScaleEnd() {
    _lastScale = 1.0;
    _lastFocal = null;
    final id = _draggingId;
    if (id == null) return;
    _draggingId = null;
    _sim?.endDrag(id);
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
  List<(String, Color)> _legendTypes(EntityMapData data) {
    const order = [
      ('person', 'Person'),
      ('location', 'Location'),
      ('vehicle', 'Vehicle'),
      ('evidence', 'Evidence'),
      ('org', 'Org'),
    ];
    final present = data.nodes.map((n) => n.type).toSet();
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

// ═══════════════════════════════════════════════════════════
//  Graph overlays: pill buttons, filter panel, search overlay,
//  focus bar, legend
// ═══════════════════════════════════════════════════════════════

/// Small round icon pill used for the graph's top-right controls.
class _GraphPill extends StatelessWidget {
  const _GraphPill({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? AppColors.brandBlue.withValues(alpha: 0.18) : AppColors.overlayPanel,
            border: Border.all(
              color: active ? AppColors.brandBlue : AppColors.consoleBorder,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: active ? AppColors.brandBlue : AppColors.consoleMuted,
          ),
        ),
      ),
    );
  }
}

/// Entity-type + relationship-type filter chips (v3 vault-chips pattern).
/// Toggling a chip hides/shows that type in the graph.
class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.nodes,
    required this.edges,
    required this.hiddenTypes,
    required this.hiddenRelTypes,
    required this.onChanged,
  });

  final List<MapNode> nodes;
  final List<MapEdge> edges;
  final Set<String> hiddenTypes;
  final Set<String> hiddenRelTypes;
  final VoidCallback onChanged;

  static const _typeOrder = [
    ('person', 'Person'),
    ('location', 'Location'),
    ('vehicle', 'Vehicle'),
    ('evidence', 'Evidence'),
    ('org', 'Org'),
  ];

  @override
  Widget build(BuildContext context) {
    final types = <(String, String)>[
      for (final t in _typeOrder)
        if (nodes.any((n) => n.type == t.$1)) t,
      for (final t in nodes.map((n) => n.type).toSet())
        if (!_typeOrder.any((o) => o.$1 == t)) (t, t),
    ];
    final relTypes = edges.map((e) => e.type).toSet().toList()..sort();

    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.overlayPanelSolid,
        border: Border.all(color: AppColors.consoleBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ENTITY TYPES',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.consoleMuted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (type, label) in types)
                  FilterChip(
                    key: Key('graph-filter-$type'),
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: !hiddenTypes.contains(type),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (on) {
                      on ? hiddenTypes.remove(type) : hiddenTypes.add(type);
                      onChanged();
                    },
                  ),
              ],
            ),
            if (relTypes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'RELATIONSHIPS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.consoleMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final rt in relTypes)
                    FilterChip(
                      key: Key('graph-filter-rel-$rt'),
                      label: Text(
                        rt.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: !hiddenRelTypes.contains(rt),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (on) {
                        on
                            ? hiddenRelTypes.remove(rt)
                            : hiddenRelTypes.add(rt);
                        onChanged();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Find-entity overlay: type-ahead over visible node names; picking a
/// match centers the camera on it and flashes its neighborhood.
class _SearchOverlay extends StatelessWidget {
  const _SearchOverlay({
    required this.controller,
    required this.nodes,
    required this.onPick,
    required this.onClose,
  });

  final TextEditingController controller;
  final List<MapNode> nodes;
  final ValueChanged<MapNode> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final query = controller.text.toLowerCase().trim();
    final matches = query.isEmpty
        ? const <MapNode>[]
        : nodes
              .where((n) => n.name.toLowerCase().contains(query))
              .take(5)
              .toList(growable: false);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.overlayPanelSolid,
        border: Border.all(color: AppColors.consoleBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('graph-search-field'),
            controller: controller,
            autofocus: true,
            style: const TextStyle(
              color: AppColors.consoleText,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Jump to entity…',
              hintStyle: const TextStyle(
                color: AppColors.consoleMuted,
                fontSize: 12,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 16,
                color: AppColors.consoleMuted,
              ),
              suffixIcon: IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 14),
                color: AppColors.consoleMuted,
                onPressed: onClose,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          for (final node in matches)
            ListTile(
              key: Key('graph-search-hit-${node.id}'),
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.circle_outlined,
                size: 14,
                color: _GraphPainter.nodeColor(node.type),
              ),
              title: Text(
                node.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.consoleText,
                  fontSize: 12.5,
                ),
              ),
              onTap: () => onPick(node),
            ),
        ],
      ),
    );
  }
}

/// Depth selector shown while local-graph (focus) mode is active.
class _FocusBar extends StatelessWidget {
  const _FocusBar({
    required this.depth,
    required this.focused,
    required this.onDepth,
    required this.onClear,
  });

  final int depth;
  final bool focused;
  final ValueChanged<int> onDepth;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.overlayPanelSolid,
        border: Border.all(color: AppColors.consoleBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in const [1, 2, 3])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ChoiceChip(
                label: Text(
                  '$d hop${d > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11),
                ),
                selected: depth == d,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onDepth(d),
              ),
            ),
          if (focused)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Clear focus',
              icon: const Icon(Icons.close, size: 15),
              color: AppColors.consoleMuted,
              onPressed: onClear,
            ),
        ],
      ),
    );
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
        color: AppColors.overlayPanel,
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
    this.zoom = 1.0,
    this.pan = Offset.zero,
    this.highlight,
  });

  final EntityMapData data;
  final Map<String, Offset> positions;
  final double nodeRadius;

  /// Animation phase 0..1 — drives edge dash flow + node pulse.
  final double t;

  /// Camera: paint runs through translate(pan) · scale(zoom).
  final double zoom;
  final Offset pan;

  /// Node ids that stay bright while everything else dims (hover
  /// highlight); null disables dimming.
  final Set<String>? highlight;

  bool _dimmed(String id) => highlight != null && !highlight!.contains(id);

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
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(zoom);
    // -- Edges: flowing dashes (under nodes) --------------------------
    final edgePaint = Paint()
      ..color = AppColors.graphEdge
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const period = 11.0; // dash + gap
    final flow = -t * period;

    for (final edge in data.edges) {
      final a = positions[edge.fromId];
      final b = positions[edge.toId];
      if (a == null || b == null) continue;
      final dim = _dimmed(edge.fromId) || _dimmed(edge.toId);
      edgePaint.strokeWidth = (dim ? 0.8 : 1.4) / zoom;
      edgePaint.color = AppColors.graphEdge.withValues(
        alpha: dim ? 0.12 : 0.30,
      );
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
        AppColors.textSecondary.withValues(alpha: dim ? 0.15 : 0.75),
        fontSize: 9.5,
      );
    }

    // -- Nodes: orbs with pulse ring + glowing core --------------------
    for (final node in data.nodes) {
      final p = positions[node.id];
      if (p == null) continue;
      final dim = _dimmed(node.id);
      final color = nodeColor(node.type).withValues(alpha: dim ? 0.18 : 1.0);
      final unknown = !_knownTypes.contains(node.type);

      // Pulse ring (known types only — unknown is dashed, quiet).
      if (!unknown && !dim) {
        canvas.drawCircle(
          p,
          nodeRadius * (1.0 + 0.55 * t),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / zoom
            ..color = color.withValues(alpha: (1 - t) * 0.45),
        );
      }

      // Dark disc body.
      canvas.drawCircle(
        p,
        nodeRadius,
        Paint()..color = AppColors.overlayPanel,
      );

      // Ring — solid for known types, dashed for unknown.
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / zoom
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
        AppColors.consoleText.withValues(alpha: dim ? 0.15 : 1.0),
      );
    }
    canvas.restore();
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
      oldDelegate.data != data ||
      oldDelegate.t != t ||
      oldDelegate.zoom != zoom ||
      oldDelegate.pan != pan ||
      oldDelegate.highlight != highlight ||
      !identical(oldDelegate.positions, positions);
}
