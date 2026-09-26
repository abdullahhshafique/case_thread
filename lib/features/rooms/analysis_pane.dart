import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../alibis/alibi_providers.dart';
import '../alibis/alibi_screen.dart';
import '../contradictions/contradiction_providers.dart';
import '../contradictions/contradiction_screen.dart';
import '../investigation_gaps/gap_providers.dart';
import '../investigation_gaps/gap_screen.dart';
import 'rooms_providers.dart' show analysisTabRequestProvider;

/// Analysis section of RoomDetailScreen (Phase 5).
/// Nested tabs: Alibis, Contradictions, Investigation Gaps
/// (PRD §4.2 / §4.8). Quick Actions bar above the tabs
/// surfaces the most common investigation tasks in one swipe.
class AnalysisPane extends ConsumerStatefulWidget {
  const AnalysisPane({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<AnalysisPane> createState() => _AnalysisPaneState();
}

class _AnalysisPaneState extends ConsumerState<AnalysisPane>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Riverpod 3.4.3: ref.listen is only legal inside build (not
    // initState) — it registers the subscription for this build.
    ref.listen<int?>(analysisTabRequestProvider, (_, request) {
      if (request != null && request != _tabs.index) {
        _tabs.animateTo(request);
      }
    });
    return Column(
      children: [
        // -- Quick Actions bar ---------------------------------
        _quickActions(context),
        const SizedBox(height: AppSpacing.xs),
        // -- Nested tab bar ------------------------------------
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(key: Key('analysis-tab-alibis'), text: 'Alibis'),
            Tab(
              key: Key('analysis-tab-contradictions'),
              text: 'Contradictions',
            ),
            Tab(key: Key('analysis-tab-gaps'), text: 'Gaps'),
          ],
        ),
        const Divider(height: 1),
        // -- Tab content ---------------------------------------
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              AlibiScreen(roomId: widget.roomId),
              ContradictionScreen(roomId: widget.roomId),
              GapScreen(roomId: widget.roomId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionChip(
            key: const Key('qa-alibi'),
            icon: Icons.shield,
            label: 'Verify Alibi',
            onTap: () {
              ref.invalidate(alibiRepositoryProvider);
              _tabs.animateTo(0);
            },
          ),
          _ActionChip(
            key: const Key('qa-contradiction'),
            icon: Icons.flag,
            label: 'Review Contradiction',
            onTap: () {
              ref.invalidate(contradictionRepositoryProvider);
              _tabs.animateTo(1);
            },
          ),
          _ActionChip(
            key: const Key('qa-gap'),
            icon: Icons.report_problem_outlined,
            label: 'Review Gaps',
            onTap: () {
              ref.invalidate(gapRepositoryProvider);
              _tabs.animateTo(2);
            },
          ),
        ],
      ),
    );
  }
}

/// One pill-shaped quick action chip (Design.md §1 — amber
/// reserved for pending AI only; chips use primary/accent).
class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: scheme.onPrimary),
        label: Text(label),
        onPressed: onTap,
        backgroundColor: scheme.primary,
        labelStyle: TextStyle(color: scheme.onPrimary),
      ),
    );
  }
}
