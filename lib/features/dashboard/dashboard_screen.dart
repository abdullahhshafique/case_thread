import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart'
    show
        CaseRoom,
        CaseStatistics,
        InvestigationStatus,
        MemberStatus,
        RoomMember;
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../rooms/rooms_providers.dart'
    show RoomsLoaded, roomMembersProvider, roomsProvider;
import '../rooms/presence.dart' show roleDotColor;
import '../rooms/vault_providers.dart'
    show VaultLoaded, VaultState, vaultProvider;
import '../rooms/domain/evidence_repository.dart' show VaultEntry;
import 'alert_cards.dart';
import 'case_briefing_card.dart';
import 'dashboard_providers.dart';
import 'task_donut.dart';

/// Overview pane (Phase 6 — v3 §7): case-info hero with coverage meter,
/// six stat tiles, and the investigation graphs. All numbers come from
/// v_case_statistics (0026) / v_case_breakdown (0033) — nothing decorative.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider(roomId));
    final breakdown = ref.watch(dashboardBreakdownProvider(roomId));
    final vault = ref.watch(vaultProvider(roomId));
    final members = ref.watch(roomMembersProvider(roomId));
    final roomsState = ref.watch(roomsProvider);

    final room = roomsState is RoomsLoaded
        ? roomsState.rooms.where((r) => r.id == roomId).firstOrNull
        : null;
    final memberList = members.maybeWhen(
      data: (m) => m
          .where((m) => m.status == MemberStatus.approved)
          .toList(growable: false),
      orElse: () => const <RoomMember>[],
    );
    final (classified, total) = _coverage(vault);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeroCard(
          room: room,
          members: memberList,
          classified: classified,
          total: total,
        ),
        const SizedBox(height: AppSpacing.lg),
        CaseBriefingCard(roomId: roomId),
        const SizedBox(height: AppSpacing.lg),
        stats.maybeWhen(
          data: (s) => _StatGrid(stats: s),
          orElse: () => const _SectionSpinner(),
        ),
        const SizedBox(height: AppSpacing.xl),
        AlertCards(roomId: roomId),
        const SizedBox(height: AppSpacing.xl),
        TaskDonut(roomId: roomId),
        const SizedBox(height: AppSpacing.xl),
        _sectionTitle(context, 'Evidence by type'),
        const SizedBox(height: AppSpacing.sm),
        breakdown.maybeWhen(
          data: (b) => _EvidenceChart(byType: _bucketed(b.evidenceByType)),
          orElse: () => const _ChartSpinner(),
        ),
        const SizedBox(height: AppSpacing.xl),
        _sectionTitle(context, 'Events over time (14 days)'),
        const SizedBox(height: AppSpacing.sm),
        breakdown.maybeWhen(
          data: (b) => _EventsChart(perDay: b.eventsPerDay),
          orElse: () => const _ChartSpinner(),
        ),
      ],
    );
  }

  /// Real coverage metric: share of vault items carrying a
  /// Fact/Claim/Finding/Unknown classification (0027). Null-safe.
  static (int, int) _coverage(AsyncValue<VaultState> vault) {
    final entries = vault.maybeWhen(
      data: (state) =>
          state is VaultLoaded ? state.entries : const <VaultEntry>[],
      orElse: () => const <VaultEntry>[],
    );
    if (entries.isEmpty) return (0, 0);
    final classified = entries.where((e) => e.classification != null).length;
    return (classified, entries.length);
  }

  static Map<String, int> _bucketed(Map<String, int> raw) {
    const order = ['pdf', 'image', 'video', 'audio', 'other'];
    final out = <String, int>{};
    for (final key in order) {
      final v = raw[key] ?? 0;
      if (v > 0) out[key] = v;
    }
    return out;
  }
}

Widget _sectionTitle(BuildContext context, String label) {
  return Text(
    label,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
  );
}

// ═══════════════════════════════════════════════════════════
//  HERO (v3 §7 card-hero)
// ═══════════════════════════════════════════════════════════════

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.room,
    required this.members,
    required this.classified,
    required this.total,
  });

  final CaseRoom? room;
  final List<RoomMember> members;
  final int classified;
  final int total;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = total == 0 ? 0.0 : classified / total * 100;

    final (statusColor, statusLabel) = room == null
        ? (AppColors.v3Info, 'Loading')
        : switch (room!.investigationStatus) {
            InvestigationStatus.open => (AppColors.statusOpen, 'Open'),
            InvestigationStatus.underInvestigation => (
              AppColors.v3Ok,
              'Under Investigation',
            ),
            InvestigationStatus.review => (AppColors.v3Warn, 'Review'),
            InvestigationStatus.closed => (AppColors.statusNeutral, 'Closed'),
          };

    final lead = room == null
        ? null
        : members
              .where((m) => m.userId == room!.ownerId)
              .map((m) => m.displayName)
              .firstOrNull;

    final opened = room == null
        ? null
        : '${room!.createdAt.day} ${_months[room!.createdAt.month - 1]} '
              '${room!.createdAt.year}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.v3StatusBorder(AppColors.v3Info)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.heroBlue.withValues(alpha: 0.10), AppColors.v3DeepViolet.withValues(alpha: 0.06)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 50,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row
          Row(
            children: [
              _Pill(color: statusColor, label: statusLabel),
              const SizedBox(width: AppSpacing.sm),
              Text(
                room == null ? '' : '#${room!.id.substring(0, 4)}',
                style: text.bodySmall?.copyWith(
                  color: AppColors.consoleMuted,
                  fontFamily: 'GeistMono',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          // Case title (v3 §7: the hero card names the case).
          Text(
            room?.name ?? 'Case overview',
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Lead line
          Text(
            room == null
                ? 'Case information loads with the room.'
                : 'Lead investigator ${lead ?? '—'}'
                      '${opened == null ? '' : ' · Opened $opened'}',
            style: text.bodyMedium?.copyWith(
              color: AppColors.consoleTextSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // People
          Row(
            children: [
              _AvatarStack(members: members),
              const SizedBox(width: AppSpacing.sm + 2),
              Text(
                '${members.length} investigators in this room',
                style: text.bodySmall?.copyWith(color: AppColors.consoleMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Coverage meter
          Text(
            'Evidence classified (Fact / Claim / Finding)',
            style: text.bodySmall?.copyWith(
              color: AppColors.consoleMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 7,
                    color: Colors.white.withValues(alpha: 0.06),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct / 100),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: value.clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.brandGradient,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 44,
                child: Text(
                  '${pct.toStringAsFixed(0)}%',
                  textAlign: TextAlign.right,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.consoleText,
                    fontFamily: 'GeistMono',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                '$classified of $total vault items tagged.',
                style: text.bodySmall?.copyWith(color: AppColors.consoleMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.v3StatusBg(color),
        border: Border.all(color: AppColors.v3StatusBorder(color)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members});

  final List<RoomMember> members;

  static const _fallbackBorder = AppColors.nodeRing;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(4).toList(growable: false);
    if (shown.isEmpty) return const SizedBox(height: 26);
    // Overlapping stack via Positioned offsets — Container's margin
    // assertion rejects the negative margins an overlap would need.
    // Phase 7: dots are colored by ROLE (roleDotColor), not by index.
    const size = 26.0;
    const overlap = 9.0;
    return SizedBox(
      height: size,
      width: size * shown.length - overlap * (shown.length - 1),
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                height: size,
                width: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      roleDotColor(shown[i].roleId),
                      roleDotColor(
                        shown[i].roleId,
                      ).withValues(alpha: 0.75),
                    ],
                  ),
                  border: Border.all(color: _fallbackBorder, width: 2),
                ),
                child: Text(
                  (shown[i].displayName ?? '?').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  STAT TILES (v3 §7 stats)
// ═══════════════════════════════════════════════════════════════

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final CaseStatistics stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100
            ? 6
            : constraints.maxWidth > 700
            ? 3
            : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: columns == 2 ? 2.4 : 1.55,
          children: [
            _StatTile(
              label: 'Evidence',
              value: stats.evidenceCount,
              icon: Icons.description_outlined,
            ),
            _StatTile(
              label: 'People',
              value: stats.peopleCount,
              icon: Icons.groups_outlined,
            ),
            _StatTile(
              label: 'Events',
              value: stats.eventsCount,
              icon: Icons.schedule,
            ),
            _StatTile(
              label: 'Conflicts',
              value: stats.contradictionsCount,
              icon: Icons.warning_amber_rounded,
              tone: AppColors.v3Err,
            ),
            _StatTile(
              label: 'Gaps',
              value: stats.gapsCount,
              icon: Icons.help_outline,
              tone: AppColors.v3Violet,
            ),
            _StatTile(
              label: 'Unverified',
              value: stats.unverifiedAlibisCount,
              icon: Icons.shield_outlined,
              tone: AppColors.v3Warn,
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    this.tone,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = tone ?? AppColors.v3Info;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: text.labelMedium?.copyWith(
                    color: AppColors.consoleMuted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 10.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 14, color: accent),
            ],
          ),
          Text(
            '$value',
            style: text.headlineLarge?.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CHARTS (v3 §7 — gradient bars)
// ═══════════════════════════════════════════════════════════════

class _EvidenceChart extends StatelessWidget {
  const _EvidenceChart({required this.byType});

  final Map<String, int> byType;

  static const _barColors = [
    AppColors.accentCyan,
    AppColors.v3Indigo,
    AppColors.v3DeepViolet,
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (byType.isEmpty) {
      return const _ChartEmpty(label: 'No evidence in the vault yet.');
    }
    final max = byType.values.reduce((a, b) => a > b ? a : b);
    final entries = byType.entries.toList(growable: false);
    return Container(
      height: 204, // value text + 110 bar slot + label + paddings (no overflow)
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${entries[i].value}',
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontFamily: 'GeistMono',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    height: 110,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: entries[i].value / max),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => FractionallySizedBox(
                          heightFactor: t.clamp(0.02, 1.0),
                          child: Container(
                            width: 40,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                                bottom: Radius.circular(3),
                              ),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: _barColors,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.v3Indigo.withValues(alpha: 0.22),
                                  blurRadius: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    entries[i].key[0].toUpperCase() +
                        entries[i].key.substring(1),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.consoleMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventsChart extends StatelessWidget {
  const _EventsChart({required this.perDay});

  final Map<String, int> perDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (perDay.isEmpty) {
      return const _ChartEmpty(label: 'No events in the last 14 days.');
    }
    final keys = perDay.keys.toList()..sort();
    final max = perDay.values.reduce((a, b) => a > b ? a : b);
    return Container(
      height: 140,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final key in keys)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${perDay[key]}',
                      style: text.labelMedium?.copyWith(
                        color: AppColors.consoleMuted,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      // Bounded slot: FractionallySizedBox(heightFactor)
                      // requires finite incoming height — a bare Column
                      // child here would be unbounded.
                      height: 64,
                      width: double.infinity,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: perDay[key]! / max),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: t.clamp(0.04, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.accentCyan, AppColors.v3Indigo],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      key.substring(5),
                      style: text.labelMedium?.copyWith(
                        color: AppColors.consoleMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.consoleMuted),
      ),
    );
  }
}

class _SectionSpinner extends StatelessWidget {
  const _SectionSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ChartSpinner extends StatelessWidget {
  const _ChartSpinner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.consoleBorder),
        color: AppColors.consolePanel,
      ),
      child: const CircularProgressIndicator(),
    );
  }
}
