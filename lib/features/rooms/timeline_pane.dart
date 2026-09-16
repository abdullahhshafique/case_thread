import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models.dart' show Permission;
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
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
class TimelinePane extends ConsumerWidget {
  const TimelinePane({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(_timelineStreamProvider(roomId));
    final canEdit = ref
        .watch(myRoomPermissionsProvider(roomId))
        .maybeWhen(
          data: (p) => p.can(Permission.editCase),
          orElse: () => false,
        );
    final text = Theme.of(context).textTheme;

    return timeline.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            toAppException(error).message,
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (events) => events.isEmpty
          ? _empty(context, text)
          : ListView.builder(
              // Rules.md §9: lazy list — timelines grow unbounded.
              itemCount: events.length,
              itemBuilder: (context, index) =>
                  _TimelineTile(event: events[index], canEdit: canEdit),
            ),
    );
  }

  Widget _empty(BuildContext context, TextTheme text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.4),
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

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isAi
            ? const BorderSide(color: AppColors.statePending, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        // a11y: the affordance exists only where the policy allows it.
        onLongPress: myManualEvent ? () => _edit(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isSystem
                    ? switch (event.actionType) {
                        'evidence_uploaded' => Icons.description_outlined,
                        'code_rotated' => Icons.key_outlined,
                        'join_requested' ||
                        'join_approved' ||
                        'member_revoked' => Icons.person_outline,
                        'task_created' || 'task_updated' => Icons.checklist,
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
                        if (isAi)
                          // AI badge (Design.md §1: amber = AI suggestion,
                          // exclusively; label pairs with color — never
                          // color alone).
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
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
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
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
                                  color: Theme.of(context).colorScheme.primary,
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
                          color: text.bodyMedium?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${event.actorName ?? 'System'} · '
                              '${event.occurredAt.toLocal()}'
                          .split('.')
                          .first,
                      style: text.bodyMedium?.copyWith(
                        color: text.bodyMedium?.color?.withValues(alpha: 0.7),
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
