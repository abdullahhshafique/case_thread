import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show Alibi, AlibiStatus, Permission;
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../alibis/alibi_providers.dart';
import '../alibis/domain/alibi_repository.dart' show AlibiVerifyInput;
import 'ai_suggestions.dart';
import 'domain/evidence_repository.dart';
import 'room_permissions.dart';

/// Phase 4 (evidence detail): tapping a vault tile opens this sheet —
/// full metadata (chain-of-custody sha256, version, uploader), a
/// permission-gated "AI analysis" action scoped to this item, and a
/// Verify-Alibi section that attaches the evidence id to the alibi's
/// verification (PRD §4.2).
class EvidenceDetailSheet extends ConsumerStatefulWidget {
  const EvidenceDetailSheet({super.key, required this.roomId, required this.entry});

  final String roomId;
  final VaultEntry entry;

  static Future<void> show(
    BuildContext context,
    String roomId,
    VaultEntry entry,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: EvidenceDetailSheet(roomId: roomId, entry: entry),
      ),
    );
  }

  @override
  ConsumerState<EvidenceDetailSheet> createState() =>
      _EvidenceDetailSheetState();
}

class _EvidenceDetailSheetState extends ConsumerState<EvidenceDetailSheet> {
  bool _runningAi = false;
  String? _aiResult;
  String? _aiError;

  String? _verifyingAlibiId;

  bool get _canRunAi => ref
      .watch(myRoomPermissionsProvider(widget.roomId))
      .maybeWhen(
        data: (p) => p.can(Permission.approveAiFindings),
        orElse: () => false,
      );

  Future<void> _runAnalysis() async {
    if (_runningAi) return;
    setState(() {
      _runningAi = true;
      _aiError = null;
      _aiResult = null;
    });
    try {
      final agents = await ref
          .read(aiAgentRepositoryProvider)
          .listAgents(widget.entry.roomId);
      final agentId = agents.isNotEmpty ? agents.first.id : 'evidence_analysis';
      final suggestionId = await ref
          .read(aiAgentRepositoryProvider)
          .runAgent(
            roomId: widget.roomId,
            agentId: agentId,
            evidenceItemId: widget.entry.id,
          );
      if (!mounted) return;
      setState(() {
        _aiResult = suggestionId == null
            ? 'Analysis complete — the agent found nothing worth flagging '
                'in this item. Check the AI tab for the full report.'
            : 'Analysis complete — a new finding was added to the AI tab '
                'for review.';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _aiError = toAppException(error).message);
    } finally {
      if (mounted) setState(() => _runningAi = false);
    }
  }

  Future<void> _verifyAlibi(Alibi alibi, AlibiStatus status) async {
    final reasonController = TextEditingController(
      text: alibi.statusReason,
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Record verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Mark "${alibi.claimText}" as ${_statusLabel(status)}? '
              'A reason is required — the audit trail records it.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const Key('alibi-verify-reason'),
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Why this status? Cite the evidence.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('alibi-verify-confirm'),
            onPressed: () {
              final text = reasonController.text.trim();
              if (text.isEmpty) return;
              Navigator.of(dialogContext).pop(text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _verifyingAlibiId = alibi.id);
    try {
      await ref
          .read(alibiRepositoryProvider)
          .verify(
            alibi.id,
            AlibiVerifyInput(
              status: status,
              statusReason: reason,
              evidenceItemIds: [widget.entry.id],
            ),
          );
      ref.invalidate(alibiListProvider(widget.roomId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Alibi marked ${_statusLabel(status)} — evidence linked.',
          ),
        ),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toAppException(error).message)),
      );
    } finally {
      if (mounted) setState(() => _verifyingAlibiId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final entry = widget.entry;
    final alibis = ref.watch(alibiListProvider(widget.roomId));
    final openAlibis = alibis.maybeWhen(
      data: (list) =>
          list.where((a) => a.status != AlibiStatus.verified).toList(),
      orElse: () => const <Alibi>[],
    );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.displayName,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (entry.classification != null)
                _ClassificationChip(classification: entry.classification!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Metadata (chain-of-custody block)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
              color: AppColors.bgSurfaceRaised,
            ),
            child: Column(
              children: [
                for (final (label, value) in [
                  ('Type', entry.mimeType),
                  ('Size', _formatSize(entry.sizeBytes)),
                  ('Version', 'v${entry.version}'),
                  ('Uploaded', _shortDate(entry.uploadedAt)),
                  ('Uploader', entry.uploaderName ?? 'Member'),
                  ('SHA-256', entry.sha256),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(
                            label,
                            style: text.labelMedium?.copyWith(
                              color: AppColors.consoleMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SelectableText(
                            value,
                            style: text.bodySmall?.copyWith(
                              fontFamily: label == 'SHA-256'
                                  ? 'GeistMono'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // AI analysis (permission-gated)
          Text(
            'AI ANALYSIS',
            style: text.labelMedium?.copyWith(
              color: AppColors.consoleMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_canRunAi)
            Text(
              'You need AI-review permission to run analysis on this item.',
              style: text.bodySmall?.copyWith(color: AppColors.consoleMuted),
            )
          else ...[
            FilledButton.icon(
              key: const Key('evidence-run-ai'),
              onPressed: _runningAi ? null : _runAnalysis,
              icon: _runningAi
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 16),
              label: Text(_runningAi ? 'Analyzing…' : 'Analyze this evidence'),
            ),
            if (_aiResult != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  key: const Key('evidence-ai-result'),
                  _aiResult!,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.stateSuccess,
                  ),
                ),
              ),
            if (_aiError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _aiError!,
                  style: text.bodySmall?.copyWith(color: AppColors.stateError),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          // Verify-Alibi section
          Text(
            'VERIFY ALIBI WITH THIS EVIDENCE',
            style: text.labelMedium?.copyWith(
              color: AppColors.consoleMuted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          alibis.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, _) => Text(
              'Could not load alibis: $error',
              style: text.bodySmall?.copyWith(color: AppColors.stateError),
            ),
            data: (_) => openAlibis.isEmpty
                ? Text(
                    'No alibis waiting on verification.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.consoleMuted,
                    ),
                  )
                : Column(
                    children: [
                      for (final alibi in openAlibis)
                        _AlibiVerifyTile(
                          key: Key('alibi-verify-${alibi.id}'),
                          alibi: alibi,
                          busy: _verifyingAlibiId == alibi.id,
                          anyBusy: _verifyingAlibiId != null,
                          onVerify: (status) => _verifyAlibi(alibi, status),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _statusLabel(AlibiStatus status) => switch (status) {
    AlibiStatus.verified => 'Verified',
    AlibiStatus.partiallyVerified => 'Partially verified',
    AlibiStatus.conflict => 'Conflict',
    AlibiStatus.insufficientData => 'Insufficient data',
  };

  static String _shortDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String _formatSize(int bytes) {
    if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _AlibiVerifyTile extends StatelessWidget {
  const _AlibiVerifyTile({
    required this.alibi,
    required this.busy,
    required this.anyBusy,
    required this.onVerify,
    super.key,
  });

  final Alibi alibi;
  final bool busy;
  final bool anyBusy;
  final ValueChanged<AlibiStatus> onVerify;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        color: AppColors.bgSurfaceRaised,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            alibi.claimText,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            'Claimed ${_shortDate(alibi.claimedWindowStart)} – '
            '${_shortDate(alibi.claimedWindowEnd)} · '
            'currently ${switch (alibi.status) {
              AlibiStatus.partiallyVerified => 'partially verified',
              AlibiStatus.conflict => 'in conflict',
              AlibiStatus.insufficientData => 'insufficient data',
              AlibiStatus.verified => 'verified',
            }}',
            style: text.bodySmall?.copyWith(color: AppColors.consoleMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (status, label, color) in [
                (
                  AlibiStatus.verified,
                  'Verified',
                  AppColors.stateSuccess,
                ),
                (
                  AlibiStatus.partiallyVerified,
                  'Partial',
                  AppColors.statePending,
                ),
                (AlibiStatus.conflict, 'Conflict', AppColors.stateError),
                (
                  AlibiStatus.insufficientData,
                  'Insufficient',
                  AppColors.statusNeutral,
                ),
              ])
                OutlinedButton(
                  onPressed: busy || anyBusy ? null : () => onVerify(status),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(label, style: const TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}

class _ClassificationChip extends StatelessWidget {
  const _ClassificationChip({required this.classification});

  final String classification;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (classification) {
      'fact' => (AppColors.stateSuccess, 'Fact'),
      'claim' => (AppColors.statePending, 'Claim'),
      'finding' => (AppColors.statusOpen, 'Finding'),
      'unknown' => (AppColors.statusNeutral, 'Unknown'),
      _ => (AppColors.statusNeutral, classification),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
