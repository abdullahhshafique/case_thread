import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_providers.dart';
import 'rooms_providers.dart';

/// Audit Log pane (Phase 6 — v3 §13): the room's immutable action
/// trail (0003 append-only; member-scoped reads via 0005 RLS). Every
/// row is what happened, who did it, and when — no edit/delete exists.
class AuditPane extends ConsumerWidget {
  const AuditPane({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audit = ref.watch(roomAuditProvider(roomId));
    final members = ref.watch(roomMembersProvider(roomId));
    final text = Theme.of(context).textTheme;

    final nameByUser = members.maybeWhen(
      data: (list) => {
        for (final m in list)
          if (m.displayName != null) m.userId: m.displayName!,
      },
      orElse: () => const <String, String>{},
    );

    return audit.when(
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
      data: (rows) => rows.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('No audit entries yet', style: text.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Every action in this room is recorded here '
                    'automatically — entries cannot be edited or removed.',
                    style: text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              // Rules.md §9: bounded query (100), lazy list.
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              itemCount: rows.length,
              itemBuilder: (context, index) => _AuditTile(
                row: rows[index],
                actorName:
                    nameByUser[rows[index].actorId] ??
                    _actorFallback(rows[index]),
              ),
            ),
    );
  }

  static String _actorFallback(AuditRowData row) =>
      row.actorId == null ? 'System' : 'Member';
}

/// One audit row as the client sees it (0003 schema).
class AuditRowData {
  const AuditRowData({
    required this.id,
    required this.roomId,
    required this.actionType,
    required this.objectType,
    required this.createdAt,
    this.actorId,
    this.objectId = '',
  });

  final int id;
  final String roomId;
  final String? actorId;
  final String actionType;
  final String objectType;
  final String objectId;
  final DateTime createdAt;

  factory AuditRowData.fromMap(Map<String, dynamic> map) {
    return AuditRowData(
      id: (map['id'] as num).toInt(),
      roomId: map['room_id'] as String,
      actorId: map['actor_id'] as String?,
      actionType: (map['action_type'] as String?) ?? 'unknown',
      objectType: (map['object_type'] as String?) ?? 'object',
      objectId: (map['object_id'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// 'evidence_uploaded' → 'Evidence uploaded'.
  String get actionLabel => actionType
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String get timeLabel {
    final local = createdAt.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$mm-$dd $hh:$mi';
  }
}

final roomAuditProvider = FutureProvider.family<List<AuditRowData>, String>((
  ref,
  roomId,
) async {
  ref.watch(sessionProvider);
  try {
    final client = ref.watch(supabaseClientProvider);
    final rows = await client
        .from('audit_log')
        .select(
          'id, room_id, actor_id, action_type, object_type, object_id, '
          'created_at',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => AuditRowData.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  } catch (error) {
    throw toAppException(error);
  }
});

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.row, required this.actorName});

  final AuditRowData row;
  final String actorName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.v3StatusBg(AppColors.v3Info),
              border: Border.all(
                color: AppColors.v3StatusBorder(AppColors.v3Info),
              ),
            ),
            child: Icon(
              _iconFor(row.actionType),
              size: 16,
              color: AppColors.v3Info,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.actionLabel,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.objectType.replaceAll('_', ' ')} · $actorName',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.consoleMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            row.timeLabel,
            style: text.bodySmall?.copyWith(
              color: AppColors.consoleMuted,
              fontFamily: 'GeistMono',
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String action) => switch (action) {
    'evidence_uploaded' => Icons.description_outlined,
    'code_rotated' => Icons.key_outlined,
    'join_requested' || 'join_approved' => Icons.person_add_alt_1_outlined,
    'member_revoked' => Icons.person_remove_outlined,
    'task_created' || 'task_updated' => Icons.checklist,
    'room_created' => Icons.hub_outlined,
    'timeline_event_edited' => Icons.edit_outlined,
    _ => Icons.bolt_outlined,
  };
}
