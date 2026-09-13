import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'ai_suggestions.dart';
import 'room_permissions.dart';

/// AI workflow pane (Phase 3): run agents, review suggestions.
/// Amber = PENDING AI suggestion, exclusively (Design.md §1) — never a
/// generic accent. Suggestions are visually distinct from confirmed
/// case data (Phase-3 DoD) until a Lead-tier human disposes of them.
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
    final canReview = ref
        .watch(canReviewAiProvider(widget.roomId))
        .maybeWhen(data: (v) => v, orElse: () => false);
    final canRun = ref
        .watch(myRoomPermissionsProvider(widget.roomId))
        .maybeWhen(data: (p) => p.roleId != null, orElse: () => false);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
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
                    onPressed: (_running || !canRun)
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
                          onReview: (decision) => _review(context, s, decision),
                        ),
                    ],
                  ),
            orElse: () => const CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context, AgentDefinition agent) async {
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
      if (mounted) {
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
  ) async {
    try {
      await ref
          .read(aiAgentRepositoryProvider)
          .reviewSuggestion(suggestionId: s.id, decision: decision);
      ref.invalidate(suggestionsProvider(widget.roomId));
    } catch (error) {
      if (context.mounted) {
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
  final bool canReview;
  final void Function(String decision) onReview;

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
                    onPressed: () => onReview('dismissed'),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton.icon(
                    key: Key('ai-accept-${suggestion.id}'),
                    onPressed: () => onReview('accepted'),
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
}
