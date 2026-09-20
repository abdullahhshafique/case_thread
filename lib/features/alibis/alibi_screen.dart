import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Alibi, AlibiStatus, Permission;
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../connections/connections_providers.dart'
    show MapNode, entityMapProvider;
import '../rooms/room_permissions.dart';
import 'alibi_providers.dart';
import 'domain/alibi_repository.dart' show AlibiCreateInput;

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
              onPressed: () => _openCreateSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Record Alibi'),
            ),
          ],
        ],
      ),
    );
  }

  /// Record-alibi flow: person (from the connections map), claim text,
  /// and the claimed window. Inserts under the 0028 RLS (edit_case) and
  /// refreshes the list.
  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    final persons = ref
        .read(entityMapProvider(roomId))
        .maybeWhen(
          data: (d) => d.nodes.where((n) => n.type == 'person').toList(),
          orElse: () => const <MapNode>[],
        );
    if (persons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'An alibi is claimed by a person — add people on the '
            'Connections tab first.',
          ),
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final claimController = TextEditingController();
    String? entityId;
    DateTime? start;
    DateTime? end;

    Future<void> pick({required bool isStart}) async {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: now.subtract(const Duration(days: 365)),
        lastDate: now,
      );
      if (date == null) return;
      final time = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 20, minute: 0),
      );
      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
      if (isStart) {
        start = dt;
      } else {
        end = dt;
      }
    }

    String fmt(DateTime? dt) => dt == null
        ? 'Pick date & time'
        : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
              '${dt.day.toString().padLeft(2, '0')} '
              '${dt.hour.toString().padLeft(2, '0')}:'
              '${dt.minute.toString().padLeft(2, '0')}';

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
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Record alibi',
                    style: Theme.of(sheetContext).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    key: const Key('alibi-entity'),
                    value: entityId,
                    decoration: const InputDecoration(
                      labelText: 'Person claiming the alibi',
                    ),
                    items: [
                      for (final p in persons)
                        DropdownMenuItem(value: p.id, child: Text(p.name)),
                    ],
                    onChanged: (v) => setSheetState(() => entityId = v),
                    validator: (v) =>
                        v == null ? 'Pick who claims this alibi.' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const Key('alibi-claim'),
                    controller: claimController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Claim',
                      hintText: 'e.g. Was at home from 8:30 to 9:00 PM',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'State the claim.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    key: const Key('alibi-window-start'),
                    onPressed: () async {
                      await pick(isStart: true);
                      setSheetState(() {});
                    },
                    child: Text(
                      'From: ${fmt(start)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  OutlinedButton(
                    key: const Key('alibi-window-end'),
                    onPressed: () async {
                      await pick(isStart: false);
                      setSheetState(() {});
                    },
                    child: Text(
                      'Until: ${fmt(end)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('alibi-save'),
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        if (start == null || end == null) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Set both ends of the window.'),
                            ),
                          );
                          return;
                        }
                        Navigator.of(sheetContext).pop(true);
                      },
                      child: const Text('Record alibi'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Locals for promotion: the sheet closures captured the originals,
    // so the null check above doesn't promote those.
    final entity = entityId;
    final windowStart = start;
    final windowEnd = end;
    final claimText = claimController.text.trim();
    claimController.dispose();
    if (saved != true ||
        entity == null ||
        windowStart == null ||
        windowEnd == null) {
      return;
    }
    try {
      await ref
          .read(alibiRepositoryProvider)
          .create(
            roomId,
            AlibiCreateInput(
              entityId: entity,
              windowStart: windowStart,
              windowEnd: windowEnd,
              claimText: claimText,
              source: 'statement',
            ),
          );
      ref.invalidate(alibiListProvider(roomId));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Alibi recorded.')));
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${toAppException(error).message}\n— $error')),
        );
      }
    }
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
