import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'ai_suggestions.dart';
import 'room_permissions.dart';
import 'workflows.dart';

/// AI workflow pane (Phase 3): build agent chains, run agents, review
/// suggestions. Amber = PENDING AI suggestion, exclusively (Design.md
/// §1) — never a generic accent. Suggestions are visually distinct
/// from confirmed case data (Phase-3 DoD) until a Lead-tier human
/// disposes of them.
class AiPane extends ConsumerStatefulWidget {
  const AiPane({super.key, required this.roomId, required this.caseType});

  final String roomId;
  final String caseType;

  @override
  ConsumerState<AiPane> createState() => _AiPaneState();
}

class _AiPaneState extends ConsumerState<AiPane> {
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final agents = ref.watch(agentsProvider(widget.caseType));
    final suggestions = ref.watch(suggestionsProvider(widget.roomId));
    final workflows = ref.watch(workflowsProvider(widget.roomId));
    final perms = ref.watch(myRoomPermissionsProvider(widget.roomId));
    final canReview = perms.maybeWhen(
      data: (p) => p.can(Permission.approveAiFindings),
      orElse: () => false,
    );
    // Agents/workflows are triggered by edit_case holders — the same
    // tier the Edge Function enforces (UI hides; DB refuses).
    final canEdit = perms.maybeWhen(
      data: (p) => p.can(Permission.editCase),
      orElse: () => false,
    );
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // -- Workflows (the builder) ---------------------------------
          Row(
            children: [
              Expanded(child: Text('Workflows', style: text.headlineSmall)),
              if (canEdit)
                FilledButton.tonalIcon(
                  key: const Key('ai-workflow-new'),
                  onPressed: () => _openBuilder(context, agents.value ?? []),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chain agents into a pipeline. Every step still lands as a '
            'separate pending suggestion for human review.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          workflows.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(
                      canEdit
                          ? 'No workflows yet — build one to chain agents.'
                          : 'No workflows yet in this room.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(
                    children: [
                      for (final wf in list)
                        _WorkflowCard(
                          workflow: wf,
                          agents: agents.value ?? [],
                          canEdit: canEdit,
                          running: _running,
                          onRun: () => _runWorkflow(context, wf),
                          onDelete: () => _deleteWorkflow(context, wf),
                        ),
                    ],
                  ),
            orElse: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          // -- Single agents ------------------------------------------
          Text('Run an agent', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Agents surface possible findings for human review. Nothing '
            'enters the case record until a Lead-tier member approves it.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          agents.maybeWhen(
            data: (list) => Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final agent in list)
                  OutlinedButton.icon(
                    key: Key('ai-run-${agent.id}'),
                    onPressed: (_running || !canEdit)
                        ? null
                        : () => _run(context, agent),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(agent.displayName),
                  ),
              ],
            ),
            orElse: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          ),
          const Divider(height: AppSpacing.xxl),

          // -- Findings ------------------------------------------------
          Text('Findings', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          suggestions.maybeWhen(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No findings yet. Run an agent to analyze the case.',
                      style: text.bodyMedium,
                    ),
                  )
                : Column(
                    children: [
                      for (final s in list)
                        _SuggestionTile(
                          suggestion: s,
                          canReview: canReview,
                          onReview: (decision, edited) =>
                              _review(context, s, decision, edited),
                        ),
                    ],
                  ),
            orElse: () => const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }

  Future<void> _openBuilder(
    BuildContext context,
    List<AgentDefinition> agents,
  ) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _WorkflowBuilderSheet(roomId: widget.roomId, agents: agents),
    );
    if (created == true) {
      ref.invalidate(workflowsProvider(widget.roomId));
    }
  }

  Future<void> _runWorkflow(BuildContext context, AiWorkflow wf) async {
    // AI consent step (PRD §19): confirm before running a
    // workflow that chains multiple agents.
    final consented = await showDialog<bool>(
      context: context,
      builder: (context) => _WorkflowConsentDialog(name: wf.name),
    );
    if (consented != true) return;

    setState(() => _running = true);
    try {
      final result = await ref
          .read(aiWorkflowRepositoryProvider)
          .runWorkflow(wf.id);
      ref.invalidate(suggestionsProvider(widget.roomId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${wf.name}" finished — ${result.suggestionsCreated} '
            'finding(s) flagged for review.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _deleteWorkflow(BuildContext context, AiWorkflow wf) async {
    try {
      await ref.read(aiWorkflowRepositoryProvider).deleteWorkflow(wf.id);
      ref.invalidate(workflowsProvider(widget.roomId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _run(BuildContext context, AgentDefinition agent) async {
    // AI consent step (PRD §19): before any agent runs, surface
    // what data will be accessed and require explicit confirmation.
    final consented = await showDialog<bool>(
      context: context,
      builder: (context) => _ConsentDialog(agent: agent),
    );
    if (consented != true) return;

    setState(() => _running = true);
    try {
      final id = await ref
          .read(aiAgentRepositoryProvider)
          .runAgent(roomId: widget.roomId, agentId: agent.id);
      ref.invalidate(suggestionsProvider(widget.roomId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            id == null
                ? '"${agent.displayName}" found nothing worth flagging.'
                : '"${agent.displayName}" flagged a finding for review.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _review(
    BuildContext context,
    AiSuggestion s,
    String decision,
    Map<String, dynamic>? edited,
  ) async {
    try {
      await ref
          .read(aiAgentRepositoryProvider)
          .reviewSuggestion(
            suggestionId: s.id,
            decision: decision,
            editedOutput: edited,
          );
      ref.invalidate(suggestionsProvider(widget.roomId));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

/// One saved chain: name, agent chips joined by →, run + delete
/// (edit_case), and the latest run line (live via realtime).
class _WorkflowCard extends ConsumerWidget {
  const _WorkflowCard({
    required this.workflow,
    required this.agents,
    required this.canEdit,
    required this.running,
    required this.onRun,
    required this.onDelete,
  });

  final AiWorkflow workflow;
  final List<AgentDefinition> agents;
  final bool canEdit;
  final bool running;
  final VoidCallback onRun;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(workflowRunsProvider(workflow.roomId));
    final text = Theme.of(context).textTheme;
    final latestRun = runs.maybeWhen(
      data: (list) =>
          list.where((r) => r.workflowId == workflow.id).firstOrNull,
      orElse: () => null,
    );

    return Card(
      key: Key('ai-workflow-${workflow.id}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    workflow.name,
                    style: text.bodyLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEdit) ...[
                  IconButton(
                    key: Key('ai-workflow-delete-${workflow.id}'),
                    tooltip: 'Delete workflow',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    key: Key('ai-workflow-run-${workflow.id}'),
                    onPressed: running ? null : onRun,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Run'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (var i = 0; i < workflow.steps.length; i++) ...[
                  if (i > 0)
                    Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: text.bodySmall?.color?.withValues(alpha: 0.5),
                    ),
                  _agentChip(context, workflow.steps[i]),
                ],
              ],
            ),
            if (latestRun != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Last run: ${latestRun.status} '
                '(${latestRun.stepsDone}/${latestRun.stepsTotal} steps)',
                style: text.bodySmall?.copyWith(
                  color: latestRun.isRunning
                      ? AppColors.statePending
                      : latestRun.status == 'failed'
                      ? AppColors.stateError
                      : AppColors.stateSuccess,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _agentChip(BuildContext context, String agentId) {
    final display = agents
        .where((a) => a.id == agentId)
        .map((a) => a.displayName)
        .firstOrNull;
    return Chip(
      label: Text(display ?? agentId),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The builder sheet: name + ordered agent steps (add/remove), saved
/// via the 0018 RLS (edit_case enforced server-side too).
class _WorkflowBuilderSheet extends ConsumerStatefulWidget {
  const _WorkflowBuilderSheet({required this.roomId, required this.agents});

  final String roomId;
  final List<AgentDefinition> agents;

  @override
  ConsumerState<_WorkflowBuilderSheet> createState() =>
      _WorkflowBuilderSheetState();
}

class _WorkflowBuilderSheetState extends ConsumerState<_WorkflowBuilderSheet> {
  final _name = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<String> _steps = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        // Keep the sheet above the on-screen keyboard.
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New workflow', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('ai-workflow-name'),
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Workflow name',
                hintText: 'e.g. Contradictions, then root causes',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Give the workflow a name.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Agent steps (run in order)', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            if (_steps.isEmpty)
              Text(
                'Add at least one agent step.',
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            for (var i = 0; i < _steps.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Text('${i + 1}.', style: text.bodyLarge),
                title: Text(
                  widget.agents
                          .where((a) => a.id == _steps[i])
                          .map((a) => a.displayName)
                          .firstOrNull ??
                      _steps[i],
                ),
                trailing: IconButton(
                  tooltip: 'Remove step',
                  onPressed: () => setState(() => _steps.removeAt(i)),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                ),
              ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final agent in widget.agents)
                  ActionChip(
                    key: Key('ai-workflow-add-${agent.id}'),
                    label: Text(agent.displayName),
                    onPressed: _steps.length >= 5
                        ? null
                        : () => setState(() => _steps.add(agent.id)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('ai-workflow-save'),
                onPressed: (_saving || _steps.isEmpty) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save workflow'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(aiWorkflowRepositoryProvider)
          .saveWorkflow(
            roomId: widget.roomId,
            name: _name.text.trim(),
            steps: _steps,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.canReview,
    required this.onReview,
  });

  final AiSuggestion suggestion;

  /// Whether the caller holds approve_ai_findings (Lead tier).
  final bool canReview;

  /// decision: accepted | edited | dismissed. For 'edited', the second
  /// value carries the HUMAN-edited output map.
  final void Function(String decision, Map<String, dynamic>? edited) onReview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pending = suggestion.isPending;

    return Card(
      key: Key('ai-sug-${suggestion.id}'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      // Amber border ONLY for pending AI suggestions (Design.md §1).
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: pending
              ? AppColors.statePending
              : Theme.of(context).colorScheme.surface,
          width: pending ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pending ? Icons.hourglass_top_outlined : Icons.task_alt,
                  size: 20,
                  color: pending
                      ? AppColors.statePending
                      : AppColors.stateSuccess,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    suggestion.title ?? suggestion.agentType,
                    style: text.bodyLarge,
                  ),
                ),
                // Status label paired with the icon — never color alone.
                Text(
                  pending ? 'AI suggestion' : suggestion.status,
                  style: text.labelMedium?.copyWith(
                    color: pending
                        ? AppColors.statePending
                        : AppColors.stateSuccess,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            if (suggestion.detail?.isNotEmpty == true)
              Text(suggestion.detail!, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${suggestion.agentType} · ${suggestion.createdAt.toLocal()}'
                  .split('.')
                  .first,
              style: text.bodyMedium?.copyWith(
                color: text.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
            if (pending && canReview) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: Key('ai-dismiss-${suggestion.id}'),
                    onPressed: () => onReview('dismissed', null),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  OutlinedButton.icon(
                    key: Key('ai-edit-${suggestion.id}'),
                    onPressed: () => _openEditDialog(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit & accept'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    key: Key('ai-accept-${suggestion.id}'),
                    onPressed: () => onReview('accepted', null),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Edit-and-accept (0017 'edited' path): the Lead corrects the AI's
  /// wording; the HUMAN version is what gets promoted to the timeline.
  Future<void> _openEditDialog(BuildContext context) async {
    final edited = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditSuggestionDialog(suggestion: suggestion),
    );
    if (edited != null) {
      onReview('edited', edited);
    }
  }
}

/// Pre-filled with the AI output; the submitted map preserves the
/// original provenance (provider/model/agent) while replacing the
/// human-facing text fields.
class _EditSuggestionDialog extends StatefulWidget {
  const _EditSuggestionDialog({required this.suggestion});

  final AiSuggestion suggestion;

  @override
  State<_EditSuggestionDialog> createState() => _EditSuggestionDialogState();
}

class _EditSuggestionDialogState extends State<_EditSuggestionDialog> {
  late final TextEditingController _title;
  late final TextEditingController _detail;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.suggestion.title ?? '');
    _detail = TextEditingController(text: widget.suggestion.detail ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit finding'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your edited version is what enters the case record. The '
              'original AI output stays preserved in the suggestion.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('ai-edit-title'),
              controller: _title,
              maxLines: 1,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'The finding needs a title.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('ai-edit-detail'),
              controller: _detail,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Detail',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('ai-edit-submit'),
          onPressed: _submit,
          child: const Text('Save & accept'),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop({
      'title': _title.text.trim(),
      'detail': _detail.text.trim(),
      // Provenance preserved: the review trail shows what the AI
      // proposed vs what the human accepted.
      'agent_type': widget.suggestion.agentType,
      if (widget.suggestion.provider != null)
        'provider': widget.suggestion.provider,
      'human_edited': true,
    });
  }
}

/// AI consent dialog (PRD §19): before ANY agent runs, this shows
/// what data the server will access and asks for explicit
/// confirmation. The Edge Function independently re-derives the
/// scope from the caller's RLS scope (defense in depth).
class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog({required this.agent});

  final AgentDefinition agent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('AI consent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Run "${agent.displayName}"?', style: text.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This agent will access data in this room to produce its '
            'finding. The server will only read data you can already '
            'see (timeline events, evidence items, entities, members) '
            'and will send exactly that to the AI provider.',
            style: text.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('ai-consent-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

/// AI consent for workflows (PRD §19): same scope
/// disclosure, adapted for a multi-agent chain.
class _WorkflowConsentDialog extends StatelessWidget {
  const _WorkflowConsentDialog({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('AI consent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Run workflow "$name"?', style: text.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This workflow will run multiple agents that each '
            'access data in this room. The server will only read '
            'data you can already see (timeline events, evidence '
            'items, entities, members) and will send exactly '
            'that to the AI provider for each step.',
            style: text.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('ai-workflow-consent-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
