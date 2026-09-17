import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import 'dashboard_providers.dart';

/// Dashboard screen (Phase 5): stat tiles + case info.
/// Shown as a new tab or route (PRD §8–9).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider(roomId));
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: stats.when(
        data: (stats) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('Case Dashboard', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatTile(
                  label: 'Evidence',
                  value: stats.evidenceCount,
                  icon: Icons.folder_outlined,
                ),
                _StatTile(
                  label: 'People',
                  value: stats.peopleCount,
                  icon: Icons.people_outlined,
                ),
                _StatTile(
                  label: 'Locations',
                  value: stats.locationsCount,
                  icon: Icons.location_on_outlined,
                ),
                _StatTile(
                  label: 'Events',
                  value: stats.eventsCount,
                  icon: Icons.timeline,
                ),
                _StatTile(
                  label: 'Contradictions',
                  value: stats.contradictionsCount,
                  icon: Icons.warning_amber,
                ),
                _StatTile(
                  label: 'Gaps',
                  value: stats.gapsCount,
                  icon: Icons.report_problem_outlined,
                ),
                _StatTile(
                  label: 'AI Findings',
                  value: stats.aiFindingsCount,
                  icon: Icons.auto_awesome_outlined,
                ),
              ],
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Unable to load dashboard: $error')),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text('$value', style: text.headlineMedium),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
