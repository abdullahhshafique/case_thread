import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart'
    show CaseRoom, InvestigationStatus, RoomMember;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/rooms_providers.dart'
    show RoomsLoaded, roomMembersProvider, roomsProvider;
import 'dashboard_providers.dart';

/// Case Dashboard (Phase 6, doc §8–9): case-info header, stat tiles,
/// and investigation-oriented graphs. Doc §32 puts Dashboard first in
/// navigation — it is the central overview of the investigation.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider(roomId));
    final breakdown = ref.watch(dashboardBreakdownProvider(roomId));
    final roomsState = ref.watch(roomsProvider);
    final members = ref.watch(roomMembersProvider(roomId));
    final text = Theme.of(context).textTheme;

    final room = roomsState is RoomsLoaded
        ? roomsState.rooms.where((r) => r.id == roomId).firstOrNull
        : null;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        // -- Case info header (doc §8) ------------------------------
        if (room != null) _caseHeader(context, room, members.value ?? const []),

        // -- Statistics (doc §8) ------------------------------------
        Text('Statistics', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        stats.maybeWhen(
          data: (s) => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _StatTile(label: 'Evidence', value: s.evidenceCount, icon: Icons.folder_outlined),
              _StatTile(label: 'People', value: s.peopleCount, icon: Icons.people_outlined),
              _StatTile(label: 'Locations', value: s.locationsCount, icon: Icons.location_on_outlined),
              _StatTile(label: 'Events', value: s.eventsCount, icon: Icons.timeline),
              _StatTile(label: 'Contradictions', value: s.contradictionsCount, icon: Icons.warning_amber),
              _StatTile(label: 'Gaps', value: s.gapsCount, icon: Icons.report_problem_outlined),
              _StatTile(label: 'Unverified alibis', value: s.unverifiedAlibisCount, icon: Icons.shield_outlined),
              _StatTile(label: 'AI findings', value: s.aiFindingsCount, icon: Icons.auto_awesome_outlined),
            ],
          ),
          orElse: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),

        // -- Graph: evidence by type (doc §9) ------------------------
        const SizedBox(height: AppSpacing.lg),
        Text('Evidence by type', style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        breakdown.maybeWhen(
          data: (b) => _BarChartH(
            data: _groupEvidence(b.evidenceByType),
            color: AppColors.accentPrimary,
          ),
          orElse: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),

        // -- Graph: events over time (doc §9) ------------------------
        const SizedBox(height: AppSpacing.lg),
        Text('Events over time (14 days)', style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        breakdown.maybeWhen(
          data: (b) => _BarChartV(data: b.eventsPerDay, color: AppColors.accentPrimary),
          orElse: () => const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    );
  }

  Widget _caseHeader(
    BuildContext context,
    CaseRoom room,
    List<RoomMember> members,
  ) {
    final lead = members
        .where((m) => m.userId == room.ownerId)
        .map((m) => m.displayName ?? 'Owner')
        .firstOrNull;
    final teamCount = members.where((m) => m.status.name == 'approved').length;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.name, style: text.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StatusChip(status: room.investigationStatus),
                Text('Room status: ${room.status}', style: text.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lead: ${lead ?? '—'} · Team: $teamCount · '
              'Opened ${_fmtDate(room.createdAt)}',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Buckets raw mime groups into the doc §9 categories.
  static Map<String, int> _groupEvidence(Map<String, int> raw) {
    const order = ['pdf', 'image', 'video', 'audio', 'other'];
    final out = <String, int>{};
    for (final key in order) {
      final v = raw[key] ?? 0;
      if (v > 0) out[key] = v;
    }
    return out;
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Investigation-status chip — label + color, never color alone.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InvestigationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      InvestigationStatus.open => (AppColors.statusOpen, Icons.play_circle_outline),
      InvestigationStatus.underInvestigation => (AppColors.stateSuccess, Icons.search),
      InvestigationStatus.review =>
        (AppColors.statePending, Icons.rate_review_outlined),
      InvestigationStatus.closed => (AppColors.statusNeutral, Icons.check_circle_outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status.name.replaceAll('_', ' ').toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: SizedBox(
          width: 96,
          child: Column(
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: AppSpacing.xxs),
              Text('$value', style: text.headlineSmall),
              Text(label, style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal bar chart — hand-drawn (no chart dependency); the max
/// bar scales to the largest bucket, label + value always visible.
class _BarChartH extends StatelessWidget {
  const _BarChartH({required this.data, required this.color});

  final Map<String, int> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text('No evidence yet.',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final max = data.values.reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final e in data.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                    width: 64,
                    child: Text(e.key,
                        style: Theme.of(context).textTheme.bodySmall)),
                Expanded(
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: max == 0 ? 0 : e.value / max,
                        child: Container(
                          height: 16,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text('${e.value}',
                                style: Theme.of(context).textTheme.labelSmall),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Vertical bar chart for events-per-day, sorted chronologically.
class _BarChartV extends StatelessWidget {
  const _BarChartV({required this.data, required this.color});

  final Map<String, int> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text('No events in the last 14 days.',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }
    final keys = data.keys.toList()..sort();
    final max = data.values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final k in keys)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${data[k]}',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    FractionallySizedBox(
                      heightFactor: max == 0 ? 0 : data[k]! / max,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.75),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(k.substring(5), // MM-DD
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
