import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Permission;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/room_permissions.dart';
import '../rooms/rooms_providers.dart';
import '../rooms/briefing_editor_sheet.dart';

/// Case Briefing card (PRD Phase 2 / Phase 6).
/// Shows the room's briefing text or a muted placeholder; edit_case
/// holders get an edit affordance that opens the briefing editor.
class CaseBriefingCard extends ConsumerWidget {
  const CaseBriefingCard({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final roomsState = ref.watch(roomsProvider);
    final room = roomsState is RoomsLoaded
        ? roomsState.rooms.where((r) => r.id == roomId).firstOrNull
        : null;
    final briefing = room?.briefing;
    final canEdit = ref
        .watch(myRoomPermissionsProvider(roomId))
        .maybeWhen(data: (p) => p.can(Permission.editCase), orElse: () => false);

    return Card(
      color: AppColors.bgSurface,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'CASE BRIEFING',
                  style: text.labelMedium?.copyWith(
                    color: AppColors.consoleMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    'SHARED · TEAM',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.consoleMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (canEdit)
                  IconButton(
                    key: const Key('briefing-edit'),
                    tooltip: 'Edit briefing',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: AppColors.consoleMuted,
                    onPressed: () => BriefingEditorSheet.show(
                      context,
                      ref,
                      roomId,
                      briefing,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              briefing == null || briefing.isEmpty
                  ? 'No briefing yet.'
                  : briefing,
              style: text.bodyMedium?.copyWith(
                height: 1.65,
                color: briefing == null || briefing.isEmpty
                    ? AppColors.consoleMuted
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
