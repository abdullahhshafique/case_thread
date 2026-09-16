import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/theme/app_spacing.dart';
import 'version_history_repository.dart';

/// Version-history viewer (Phase 4, 0024): the append-only change
/// trail for one task or manual timeline event, newest last. Opened
/// from a tile's history icon.
class VersionHistorySheet extends ConsumerWidget {
  const VersionHistorySheet({
    super.key,
    required this.objectKind,
    required this.objectId,
    required this.title,
  });

  final String objectKind;
  final String objectId;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = ref.watch(objectVersionsProvider((objectKind, objectId)));
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('History', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(title, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: versions.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text(
                    toAppException(error).message,
                    textAlign: TextAlign.center,
                  ),
                ),
                data: (entries) => entries.isEmpty
                    ? Center(
                        child: Text(
                          'No changes recorded yet.',
                          style: text.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: entries.length,
                        itemBuilder: (context, index) =>
                            _VersionTile(entry: entries[index]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionTile extends StatelessWidget {
  const _VersionTile({required this.entry});

  final VersionEntry entry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              maxRadius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: Text('${entry.versionNo}', style: text.labelMedium),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(switch (entry.action) {
                    'created' => 'Created',
                    'edited' => 'Edited',
                    'status_changed' => 'Status changed',
                    _ => entry.action,
                  }, style: text.bodyLarge),
                  if (entry.detail.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      entry.detail,
                      style: text.bodyMedium?.copyWith(
                        color: text.bodyMedium?.color?.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${entry.actorName ?? 'System'} · '
                            '${entry.changedAt.toLocal()}'
                        .split('.')
                        .first,
                    style: text.bodyMedium?.copyWith(
                      color: text.bodyMedium?.color?.withValues(alpha: 0.6),
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

/// Opens the sheet from a tile's trailing history icon.
Future<void> showVersionHistory(
  BuildContext context, {
  required String objectKind,
  required String objectId,
  required String title,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => VersionHistorySheet(
      objectKind: objectKind,
      objectId: objectId,
      title: title,
    ),
  );
}
