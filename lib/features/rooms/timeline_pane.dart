import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/theme/app_spacing.dart';
import 'data/supabase_room_content_repository.dart';
import 'domain/room_content_models.dart';

/// Timeline pane (Sprint 5): merged manual + system events via
/// realtime stream (0010 mirrors audit actions automatically).
class TimelinePane extends ConsumerWidget {
  const TimelinePane({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(_timelineStreamProvider(roomId));
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
                  _TimelineTile(event: events[index]),
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

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.event});

  final TimelineEventModel event;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isSystem = event.eventType == 'system';

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
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
                  : Icons.event_note,
              color: isSystem
                  ? Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.5)
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.displaySummary, style: text.bodyLarge),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
