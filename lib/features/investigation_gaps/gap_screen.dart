import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart'
    show GapStatus, InvestigationGap, Permission;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/room_permissions.dart';
import 'gap_providers.dart';

/// Investigation gaps screen (Phase 5): list gaps, create new
/// ones, convert to tasks. The PDF's "major feature" (§16).
class GapScreen extends ConsumerWidget {
  const GapScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gaps = ref.watch(gapListProvider(roomId));
    final perms = ref.watch(myRoomPermissionsProvider(roomId));
    final canEdit = perms.maybeWhen(
      data: (p) => p.can(Permission.editCase),
      orElse: () => false,
    );
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Investigation Gaps', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          gaps.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No gaps — case is fully covered.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(children: [for (final g in list) _GapTile(gap: g)]),
            orElse: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('gap-add'),
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Log Gap'),
            ),
          ],
        ],
      ),
    );
  }
}

class _GapTile extends ConsumerWidget {
  const _GapTile({required this.gap});

  final InvestigationGap gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final gapColor = switch (gap.status) {
      GapStatus.open => AppColors.stateError,
      GapStatus.inProgress => AppColors.statePending,
      GapStatus.resolved => AppColors.stateSuccess,
    };

    return Card(
      child: ListTile(
        title: Text(gap.description, style: text.bodyMedium),
        subtitle: Text(
          '${gap.status.name.replaceAll('_', ' ')} • type: ${gap.gapType}',
          style: text.bodySmall,
        ),
        trailing: Icon(
          Icons.report_problem_outlined,
          color: gapColor,
          size: 20,
        ),
        isThreeLine: true,
      ),
    );
  }
}
