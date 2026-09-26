import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Permission;
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../offline/offline_banner.dart';
import '../offline/offline_providers.dart';
import '../auth/auth_providers.dart';
import '../history/version_history_sheet.dart';
import 'data/supabase_room_content_repository.dart';
import 'domain/room_content_models.dart';
import 'room_permissions.dart';

/// Timeline pane (Sprint 5): merged manual + system events via
/// realtime stream (0010 mirrors audit actions automatically).
/// Phase 4: manual events editable (long-press); LWW conflict chip
/// on rows that lost an offline edit race (0023).
class TimelinePane extends ConsumerStatefulWidget {
  const TimelinePane({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<TimelinePane> createState() => _TimelinePaneState();
}

class _TimelinePaneState extends ConsumerState<TimelinePane> {
  /// Client-side classification filter (doc §7): null = All.
  String? _filter;

  /// Source filter (v3 §7): null = All; manual | system | ai_suggestion.
  String? _sourceFilter;

  @override
  Widget build(BuildContext context) {
    final roomId = widget.roomId;
    final timeline = ref.watch(_timelineStreamProvider(roomId));
    final canEdit = ref
        .watch(myRoomPermissionsProvider(roomId))
        .maybeWhen(
          data: (p) => p.can(Permission.editCase),
          orElse: () => false,
        );
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        // Classification filter chips (doc §7 — Fact/Claim/Finding/
        // Unknown made visible; 'All' clears the filter).
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              for (final f in const [
                'All',
                'fact',
                'claim',
                'finding',
                'unknown',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    key: Key('tl-filter-$f'),
                    label: Text(f == 'All' ? f : _cap(f)),
                    selected: (f == 'All') ? _filter == null : _filter == f,
                    onSelected: (_) => setState(() {
                      _filter = (f == 'All') ? null : f;
                    }),
                  ),
                ),
            ],
          ),
        ),
        _sourceChips(),
        Expanded(
          child: Stack(
            children: [
              _list(timeline, canEdit, text),
              if (canEdit)
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: FloatingActionButton.small(
                    key: const Key('timeline-add-event'),
                    tooltip: 'Add case event',
                    onPressed: () => _addEvent(context),
                    child: const Icon(Icons.add),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Source filter chips (v3 §7): manual / system / AI provenance.
  Widget _sourceChips() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          for (final f in const [
            ('all', 'All sources'),
            ('manual', 'Manual'),
            ('system', 'System'),
            ('ai_suggestion', 'AI'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                key: Key('tl-source-${f.$1}'),
                label: Text(
                  f.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        (f.$1 == 'all'
                            ? _sourceFilter == null
                            : _sourceFilter == f.$1)
                        ? AppColors.v3Info
                        : AppColors.consoleMuted,
                  ),
                ),
                selected: f.$1 == 'all'
                    ? _sourceFilter == null
                    : _sourceFilter == f.$1,
                onSelected: (_) => setState(() {
                  _sourceFilter = (f.$1 == 'all') ? null : f.$1;
                }),
                selectedColor: AppColors.v3IndigoTint,
                side: BorderSide(
                  color:
                      (f.$1 == 'all'
                          ? _sourceFilter == null
                          : _sourceFilter == f.$1)
                      ? AppColors.graphEdge
                      : AppColors.consoleBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }

  /// Classification picker sheet (doc §7): summary + Fact/Claim/
  /// Finding/Unknown choice, inserted via PostgREST under the 0005
  /// manual-event insert policy (edit_case holders only).
  Future<void> _addEvent(BuildContext context) async {
    final controller = TextEditingController();
    String? classification;
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
                'Add case event',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const Key('timeline-add-summary'),
                controller: controller,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Summary',
                  hintText:
                      'e.g. CCTV shows Vehicle V01 at Riverside Road 8:42 PM',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final c in const ['fact', 'claim', 'finding', 'unknown'])
                    ChoiceChip(
                      label: Text(_cap(c)),
                      selected: classification == c,
                      onSelected: (_) =>
                          setSheetState(() => classification = c),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('timeline-add-save'),
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Add event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (saved != true) return;
    final summary = controller.text.trim();
    if (summary.isEmpty) return;
    try {
      await ref
          .read(roomContentRepositoryProvider)
          .addManualEvent(
            roomId: widget.roomId,
            summary: summary,
            classification: classification,
          );
      ref.invalidate(_timelineStreamProvider(widget.roomId));
    } on Exception catch (error) {
      if (context.mounted) {
        // Dev posture: raw cause accompanies the calm message so a
        // failure screenshot is diagnosable without the console.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toAppException(error).message}\n— $error')),
        );
      }
    }
  }

  Widget _list(
    AsyncValue<List<TimelineEventModel>> timeline,
    bool canEdit,
    TextTheme text,
  ) {
    return timeline.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            '${toAppException(error).message}\n— $error',
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (events) {
        final filtered = events
            .where((e) => _filter == null || e.classification == _filter)
            .where((e) => _sourceFilter == null || e.eventType == _sourceFilter)
            .toList();
        if (filtered.isEmpty) return _empty(context, text);
        return ListView.builder(
          // Rules.md §9: lazy list — timelines grow unbounded.
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              _TimelineTile(event: filtered[index], canEdit: canEdit),
        );
      },
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

Widget _empty(BuildContext context, TextTheme text) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timeline,
          size: 48,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('No events yet', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Case activity appears here as the team works.',
          style: text.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

/// Realtime timeline stream (Architecture.md §8: Riverpod wraps
/// Supabase Realtime; updates arrive without pull-to-refresh).
final _timelineStreamProvider =
    StreamProvider.family<List<TimelineEventModel>, String>((ref, roomId) {
      return ref.watch(roomContentRepositoryProvider).watchTimeline(roomId);
    });

class _TimelineTile extends ConsumerWidget {
  const _TimelineTile({required this.event, required this.canEdit});

  final TimelineEventModel event;

  /// Author's own manual events only (0005 policy mirrors this).
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final isSystem = event.eventType == 'system';
    // Promoted AI findings (review_suggestion 0017) — rendered with
    // the amber AI badge so they stay distinct from confirmed data.
    final isAi = event.eventType == 'ai_suggestion';
    final me = ref.watch(sessionProvider).value;
    final myManualEvent =
        canEdit && event.eventType == 'manual' && event.actorId == me?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      // v3 §7 timeline: a spine node per row, colored by source
      // (manual = blue, system = neutral, AI = amber), connected by a
      // hairline down the case's chronology.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  height: 10,
                  width: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isAi
                        ? AppColors.statePending
                        : isSystem
                        ? AppColors.statusNeutral
                        : AppColors.statusOpen,
                    border: Border.all(
                      color: isAi
                          ? AppColors.statePending
                          : isSystem
                          ? AppColors.statusNeutral
                          : AppColors.statusOpen,
                      width: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(width: 2, color: AppColors.consoleBorder),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).colorScheme.surface,
                  border: isAi
                      ? Border.all(color: AppColors.statePending, width: 1.5)
                      : Border.all(color: AppColors.consoleBorder),
                ),
                child: InkWell(
                  // a11y: the affordance exists only where the policy
                  // allows it. The card Container already pads the row.
                  onLongPress: myManualEvent ? () => _edit(context, ref) : null,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isSystem
                            ? switch (event.actionType) {
                                'evidence_uploaded' =>
                                  Icons.description_outlined,
                                'code_rotated' => Icons.key_outlined,
                                'join_requested' ||
                                'join_approved' ||
                                'member_revoked' => Icons.person_outline,
                                'task_created' ||
                                'task_updated' => Icons.checklist,
                                _ => Icons.autorenew,
                              }
                            : isAi
                            ? Icons.auto_awesome
                            : Icons.event_note,
                        color: isSystem
                            ? Theme.of(context).colorScheme.onSurface
                                  .withValues(alpha: 0.5)
                            : isAi
                            ? AppColors.statePending
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    event.displaySummary,
                                    style: text.bodyLarge,
                                  ),
                                ),
                                if (event.classification != null)
                                  _ClassificationBadge(
                                    classification: event.classification!,
                                  ),
                                if (isAi)
                                  // AI badge (Design.md §1: amber = AI suggestion,
                                  // exclusively; label pairs with color — never
                                  // color alone).
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      'AI · reviewed',
                                      style: text.labelMedium?.copyWith(
                                        color: AppColors.statePending,
                                      ),
                                    ),
                                  ),
                                // Version history (0024) — manual events only
                                // (system/AI rows have no edit trail).
                                if (event.eventType == 'manual')
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: AppSpacing.sm,
                                    ),
                                    child: InkWell(
                                      onTap: () => showVersionHistory(
                                        context,
                                        objectKind: 'timeline_event',
                                        objectId: event.id,
                                        title: event.displaySummary,
                                      ),
                                      child: Text(
                                        'History',
                                        style: text.labelMedium?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            if (isAi && event.details?['finding'] is String)
                              Text(
                                event.details!['finding'] as String,
                                style: text.bodyMedium?.copyWith(
                                  color: text.bodyMedium?.color?.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              '${event.actorName ?? 'System'} · '
                                      '${event.occurredAt.toLocal()}'
                                  .split('.')
                                  .first,
                              style: text.labelSmall?.copyWith(
                                color: AppColors.consoleMuted,
                                fontFamily: 'GeistMono',
                              ),
                            ),
                            // Offline LWW loser: visible conflict chip (policy §4).
                            if (event.conflictFlag)
                              ConflictChip(
                                objectKind: 'timeline_event',
                                objectId: event.id,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Long-press edit sheet for the author's own manual events — the
  /// same LWW-stamped RPC the offline replay uses (0023).
  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: event.details?['summary'] as String? ?? event.displaySummary,
    );
    final summary = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit event',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: Key('timeline-edit-field-${event.id}'),
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Summary',
                hintText: 'e.g. Interview completed',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(sheetContext).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (summary == null || summary.isEmpty) return;
    try {
      await runQueuedWrite(
        ref,
        event.roomId,
        'timeline_edit',
        {'event_id': event.id, 'summary': summary},
        () => ref
            .read(roomContentRepositoryProvider)
            .editManualEvent(
              roomId: event.roomId,
              eventId: event.id,
              summary: summary,
            ),
      );
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

/// Fact/Claim/Finding/Unknown badge (Phase 6, doc §7). Label paired
/// with an outline color — never color alone (Design.md §1).
class _ClassificationBadge extends StatelessWidget {
  const _ClassificationBadge({required this.classification});

  final String classification;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (classification) {
      'fact' => (AppColors.stateSuccess, 'Fact'),
      'claim' => (AppColors.statePending, 'Claim'),
      'finding' => (AppColors.statusOpen, 'Finding'),
      'unknown' => (AppColors.statusNeutral, 'Unknown'),
      _ => (AppColors.statusNeutral, classification),
    };
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
