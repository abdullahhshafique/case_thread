import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import '../offline/offline_banner.dart';
import '../offline/offline_providers.dart';
import '../history/version_history_sheet.dart';
import 'data/supabase_room_content_repository.dart';
import 'domain/room_content_models.dart';
import '../../core/api/models.dart' show Permission;
import 'room_permissions.dart';
import 'rooms_providers.dart';

/// Tasks pane (Sprint 5): create, assign, tick done — realtime.
/// Status updates restricted by the 0005 policy (assignee may tick;
/// edit_case roles may manage); denials surface typed messages.
class TasksPane extends ConsumerStatefulWidget {
  const TasksPane({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<TasksPane> createState() => _TasksPaneState();
}

class _TasksPaneState extends ConsumerState<TasksPane> {
  final _titleController = TextEditingController();
  String? _assigneeId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(_tasksStreamProvider(widget.roomId));
    final canCreate = ref
        .watch(myRoomPermissionsProvider(widget.roomId))
        .maybeWhen(
          data: (p) => p.can(Permission.editCase),
          orElse: () => false,
        );
    final members = ref.watch(roomMembersProvider(widget.roomId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              key: const Key('tasks-new'),
              onPressed: () => _showCreateSheet(context, members.value ?? []),
              icon: const Icon(Icons.add_task),
              label: const Text('New task'),
            )
          : null,
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              toAppException(error).message,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) => list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.checklist,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text('No tasks yet', style: text.headlineSmall),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) => _TaskTile(task: list[index]),
              ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context, dynamic members) {
    showModalBottomSheet<void>(
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
              'New task',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('tasks-title-field'),
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Interview the witness',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: const Key('tasks-assignee-field'),
              initialValue: _assigneeId,
              decoration: const InputDecoration(labelText: 'Assignee'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ...members.map<DropdownMenuItem<String>>((m) {
                  return DropdownMenuItem(
                    value: m.userId,
                    child: Text(m.displayName ?? 'Member'),
                  );
                }),
              ],
              onChanged: (id) => _assigneeId = id,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              key: const Key('tasks-create-submit'),
              onPressed: () async {
                final title = _titleController.text.trim();
                if (title.isEmpty) return;
                try {
                  // Offline path: live insert; network failure queues.
                  await runQueuedWrite(
                    ref,
                    widget.roomId,
                    'task_create',
                    {'title': title, 'assignee_id': _assigneeId},
                    () => ref
                        .read(roomContentRepositoryProvider)
                        .createTask(
                          roomId: widget.roomId,
                          title: title,
                          assigneeId: _assigneeId,
                        ),
                  );
                  _titleController.clear();
                  _assigneeId = null;
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                } on AppException catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext)
                        .showSnackBar(SnackBar(content: Text(error.message)));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

final _tasksStreamProvider = StreamProvider.family<List<TaskModel>, String>((
  ref,
  roomId,
) {
  return ref.watch(roomContentRepositoryProvider).watchTasks(roomId);
});

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final TaskModel task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: CheckboxListTile(
        key: Key('task-${task.id}'),
        value: task.isDone,
        title: Text(
          task.title,
          style: task.isDone
              ? text.bodyLarge?.copyWith(decoration: TextDecoration.lineThrough)
              : text.bodyLarge,
        ),
        // Version history (0024) — audit-derived, member-visible.
        secondary: IconButton(
          tooltip: 'Version history', // a11y: labeled icon button
          icon: const Icon(Icons.history),
          onPressed: () => showVersionHistory(
            context,
            objectKind: 'task',
            objectId: task.id,
            title: task.title,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.assigneeName != null || task.dueDate != null)
              Text(
                [
                  if (task.assigneeName != null) task.assigneeName!,
                  if (task.dueDate != null)
                    'Due ${task.dueDate!.toLocal()}'.split(' ').first,
                ].join(' · '),
                style: text.bodyMedium?.copyWith(
                  color: text.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            // Offline LWW loser: visible conflict chip (policy §4).
            if (task.conflictFlag)
              ConflictChip(
                objectKind: 'task',
                objectId: task.id,
                note: task.conflictNote,
              ),
          ],
        ),
        onChanged: (checked) => runQueuedWrite(
          ref,
          task.roomId,
          'task_status',
          {'task_id': task.id, 'status': checked == true ? 'done' : 'open'},
          () => ref
              .read(roomContentRepositoryProvider)
              .updateTaskStatus(
                roomId: task.roomId,
                taskId: task.id,
                status: checked == true ? 'done' : 'open',
              ),
        ),
      ),
    );
  }
}
