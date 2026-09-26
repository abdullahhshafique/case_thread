import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/rooms_providers.dart';

/// Three alert cards stacked beneath the stat grid (PRD Phase 2):
/// Contradictions (coral), Investigation Gaps (amber), Alibi Status (mint).
class AlertCards extends ConsumerWidget {
  const AlertCards({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(attentionCountsProvider(roomId));
    return counts.when(
      loading: () => const _AlertCardShimmer(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) => Column(
        children: [
          _AlertCard(
            icon: Icons.warning_amber_rounded,
            label: '${data.openContradictions} Contradiction${data.openContradictions == 1 ? '' : 's'}',
            subtitle: 'Open contradictions needing review',
            borderColor: AppColors.v3Err,
            iconColor: AppColors.v3Err,
            muted: data.openContradictions == 0,
            onTap: data.openContradictions > 0
                ? () => _jumpToTab(context, ref, 1)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AlertCard(
            icon: Icons.help_outline,
            label: '${data.openGaps} Gap${data.openGaps == 1 ? '' : 's'}',
            subtitle: 'Investigation gaps to close',
            borderColor: AppColors.v3Warn,
            iconColor: AppColors.v3Warn,
            muted: data.openGaps == 0,
            onTap: data.openGaps > 0
                ? () => _jumpToTab(context, ref, 2)
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AlertCard(
            icon: Icons.shield_outlined,
            label: 'Alibis',
            subtitle:
                '${data.alibiConflict} conflict · ${data.alibiPartial} partial · ${data.alibiVerified} verified',
            borderColor: AppColors.stateSuccess,
            iconColor: AppColors.stateSuccess,
            muted: data.alibisToVerify == 0,
            onTap: data.alibisToVerify > 0
                ? () => _jumpToTab(context, ref, 0)
                : null,
          ),
        ],
      ),
    );
  }

  static void _jumpToTab(
    BuildContext context,
    WidgetRef ref,
    int tabIndex,
  ) {
    ref.read(analysisTabRequestProvider.notifier).request(tabIndex);
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.borderColor,
    required this.iconColor,
    required this.muted,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color borderColor;
  final Color iconColor;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: muted
                ? AppColors.borderSubtle
                : borderColor.withValues(alpha: 0.4),
          ),
          color: muted
              ? AppColors.bgSurfaceRaised
              : borderColor.withValues(alpha: 0.06),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: muted ? AppColors.consoleMuted : iconColor),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: muted ? AppColors.consoleMuted : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.consoleMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.consoleMuted),
          ],
        ),
      ),
    );
  }
}

class _AlertCardShimmer extends StatelessWidget {
  const _AlertCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 52,
            margin: EdgeInsets.only(bottom: i < 2 ? AppSpacing.sm : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.bgSurfaceRaised,
            ),
          ),
      ],
    );
  }
}
