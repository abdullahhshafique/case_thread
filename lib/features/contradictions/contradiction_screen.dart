import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart'
    show Contradiction, ContradictionStatus, Permission;
import '../../core/theme/app_spacing.dart';
import '../rooms/room_permissions.dart';
import 'contradiction_providers.dart';

/// Contradiction screen (Phase 5): flag contradictions manually,
/// review (resolve/dismiss). Part of Analysis section.
class ContradictionScreen extends ConsumerWidget {
  const ContradictionScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contradictions = ref.watch(contradictionListProvider(roomId));
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
          Text('Contradictions', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          contradictions.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No contradictions flagged yet.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(
                    children: [
                      for (final c in list)
                        _ContradictionTile(contradiction: c),
                    ],
                  ),
            orElse: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('contradiction-add'),
              onPressed: () {},
              icon: const Icon(Icons.flag),
              label: const Text('Flag Contradiction'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContradictionTile extends ConsumerWidget {
  const _ContradictionTile({required this.contradiction});

  final Contradiction contradiction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final statusColor = switch (contradiction.status) {
      ContradictionStatus.open => Colors.orange,
      ContradictionStatus.resolved => Colors.green,
      ContradictionStatus.dismissed => Colors.grey,
    };

    return Card(
      child: ListTile(
        title: Text(contradiction.conflictingDetail, style: text.bodyMedium),
        subtitle: Text(
          '${contradiction.status.name} — ${contradiction.flaggedReason}',
          style: text.bodySmall,
        ),
        trailing: Icon(Icons.warning_amber, color: statusColor, size: 20),
        isThreeLine: true,
      ),
    );
  }
}
