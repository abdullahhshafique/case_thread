import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'offline_providers.dart';

/// Offline banner (policy §2 reads: stale-until-confirmed + visible
/// "as of HH:MM" watermark). Amber = needs your attention (Design.md
/// §1 semantics — same family as the pending-AI badge).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    final depth = ref.watch(offlineQueueDepthProvider);
    final lastSynced = ref.watch(lastSyncedAtProvider);
    if (!offline) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final asOf = lastSynced == null
        ? ''
        : ' — as of ${lastSynced.toLocal()}'.split('.').first;
    final queued = depth > 0 ? ' · $depth change(s) queued' : '';

    return Material(
      color: AppColors.statePending.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_outlined, color: AppColors.statePending),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Offline$asOf$queued. Changes you make now sync when '
                'you reconnect.',
                style: text.bodyMedium?.copyWith(color: AppColors.statePending),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Amber conflict chip shown on LWW-loser rows (policy §4: "edited
/// while you were offline"). Tapping clears via clear_conflict (0023).
class ConflictChip extends ConsumerWidget {
  const ConflictChip({
    super.key,
    required this.objectKind,
    required this.objectId,
    this.note,
  });

  /// 'task' | 'timeline_event' (clear_conflict contract, 0023).
  final String objectKind;
  final String objectId;

  /// Optional explanation (tasks carry conflict_note).
  final String? note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.statePending,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              note ?? 'Edited while you were offline — a newer change won.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.statePending),
            ),
          ),
          TextButton(
            onPressed: () => _clear(context, ref),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(offlineSyncProvider).clearConflict(objectKind, objectId);
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(toAppException(error).message)));
      }
    }
  }
}
