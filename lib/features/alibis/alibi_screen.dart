import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Alibi, AlibiStatus, Permission;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/room_permissions.dart';
import 'alibi_providers.dart';

/// Alibi screen (Phase 5): list alibis, create new claims,
/// trigger verification. Tabbed within the Analysis section
/// of RoomDetailScreen (PRD §4.2).
class AlibiScreen extends ConsumerWidget {
  const AlibiScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alibis = ref.watch(alibiListProvider(roomId));
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
          Text('Alibis', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          alibis.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No alibis recorded yet.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(
                    children: [for (final a in list) _AlibiTile(alibi: a)],
                  ),
            orElse: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('alibi-add'),
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Record Alibi'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlibiTile extends ConsumerWidget {
  const _AlibiTile({required this.alibi});

  final Alibi alibi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final statusColor = switch (alibi.status) {
      AlibiStatus.verified => AppColors.stateSuccess,
      AlibiStatus.partiallyVerified => AppColors.statePending,
      AlibiStatus.conflict => AppColors.stateError,
      AlibiStatus.insufficientData => AppColors.statusNeutral,
    };

    return Card(
      child: ListTile(
        title: Text(alibi.claimText, style: text.bodyMedium),
        subtitle: Text(
          '${alibi.status.name.replaceAll('_', ' ')} — ${alibi.statusReason}',
          style: text.bodySmall,
        ),
        trailing: Icon(Icons.check_circle, color: statusColor, size: 20),
        isThreeLine: true,
      ),
    );
  }
}
