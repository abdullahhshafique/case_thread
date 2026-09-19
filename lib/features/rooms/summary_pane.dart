import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart' show CaseClosedSummary, InvestigationStatus;
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'rooms_providers.dart';

/// Summary pane (Phase 6 — v3 §13): the server-generated closed-case
/// snapshot (0026 — written once when the investigation transitions to
/// closed) plus the room's current investigation status.
class SummaryPane extends ConsumerWidget {
  const SummaryPane({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(roomClosedSummaryProvider(roomId));
    final roomsState = ref.watch(roomsProvider);
    final text = Theme.of(context).textTheme;

    final room = roomsState is RoomsLoaded
        ? roomsState.rooms.where((r) => r.id == roomId).firstOrNull
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // -- Investigation status ------------------------------------
        Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.consoleBorder),
            color: AppColors.consolePanel,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Investigation status',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.consoleMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      room == null
                          ? '—'
                          : switch (room.investigationStatus) {
                              InvestigationStatus.open => 'Open',
                              InvestigationStatus.underInvestigation =>
                                'Under Investigation',
                              InvestigationStatus.review => 'Review',
                              InvestigationStatus.closed => 'Closed',
                            },
                      style: text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                room?.investigationStatus == InvestigationStatus.closed
                    ? Icons.check_circle_outline
                    : Icons.workspace_premium_outlined,
                size: 28,
                color: room?.investigationStatus == InvestigationStatus.closed
                    ? AppColors.v3Ok
                    : AppColors.v3Info,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // -- Closed summary ------------------------------------------
        summary.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Text(toAppException(error).message, style: text.bodyMedium),
          data: (data) =>
              data == null ? _empty(context) : _summaryBlocks(context, data),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: Column(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('No closed summary yet', style: text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'When this investigation is closed, a point-in-time summary '
            'is generated automatically — it will not change even if the '
            'underlying data does.',
            style: text.bodyMedium?.copyWith(color: AppColors.consoleMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Generic renderer for the summary_json snapshot: strings become
  /// paragraphs, lists become bullets, maps become key/value rows.
  Widget _summaryBlocks(BuildContext context, CaseClosedSummary data) {
    final text = Theme.of(context).textTheme;
    final blocks = <Widget>[];
    data.summaryJson.forEach((key, value) {
      final title = key
          .replaceAll('_', ' ')
          .replaceFirstMapped(
            RegExp('^.'),
            // '^.' always matches group 0, so the bang is safe.
            (m) => m[0]!.toUpperCase(),
          );
      blocks.add(
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.consoleBorder),
            color: AppColors.consolePanel,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.bodySmall?.copyWith(
                  color: AppColors.consoleMuted,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              _value(context, value),
            ],
          ),
        ),
      );
    });
    return Column(children: blocks);
  }

  Widget _value(BuildContext context, Object? value) {
    final text = Theme.of(context).textTheme;
    if (value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in value)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: _value(context, item)),
                ],
              ),
            ),
        ],
      );
    }
    if (value is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in value.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${entry.key}'.replaceAll('_', ' '),
                      style: text.bodySmall?.copyWith(
                        color: AppColors.consoleMuted,
                      ),
                    ),
                  ),
                  Expanded(child: _value(context, entry.value)),
                ],
              ),
            ),
        ],
      );
    }
    return Text('$value', style: text.bodyMedium?.copyWith(height: 1.6));
  }
}
