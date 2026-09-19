import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_providers.dart';
import 'activity_feed.dart';
import 'ai_pane.dart';
import 'audit_pane.dart';
import 'export_report.dart';
import 'discussion_pane.dart';
import 'summary_pane.dart';
import 'tasks_pane.dart';
import 'timeline_pane.dart';
import 'vault_pane.dart';
import 'analysis_pane.dart';
import 'data/supabase_rooms_repository.dart' show roomsRepositoryProvider;
import '../dashboard/dashboard_screen.dart';
import '../connections/connections_screen.dart';
import 'rooms_providers.dart';

/// Room detail (Phase 6 — v3 console): Overview / Discussion / Evidence /
/// Timeline / Analysis / Connections / Tasks | AI / Audit Log / Members /
/// Summary tabs. Rendered embedded inside the console shell (no Scaffold)
/// or standalone as a route (AppBar chrome).
class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.caseType,
    this.embedded = false,
  });

  final String roomId;
  final String caseType;

  /// Embedded in the console shell: no Scaffold/AppBar; the v3
  /// room-head row is drawn instead.
  final bool embedded;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 11, vsync: this);

  @override
  void initState() {
    super.initState();
    // Opening the room marks it seen (clears its feed items — 0014).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(activityFeedRepositoryProvider)
          .markRoomSeen(widget.roomId)
          .catchError((_) {}); // best-effort; the feed refetches anyway
    });
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final report = await ref
          .read(exportRepositoryProvider)
          .exportRoom(widget.roomId);
      if (!context.mounted) return;
      final md = report.toMarkdown();
      await Clipboard.setData(ClipboardData(text: md));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report copied — paste it anywhere to save.'),
          ),
        );
      }
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(toAppException(error).message)));
      }
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canExport = ref
        .watch(canExportProvider(widget.roomId))
        .maybeWhen(data: (v) => v, orElse: () => false);

    final tabBar = TabBar(
      controller: _tabs,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      labelColor: AppColors.consoleText,
      unselectedLabelColor: AppColors.consoleMuted,
      indicatorColor: AppColors.brandBlue,
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(key: Key('room-tab-dashboard'), text: 'Overview'),
        Tab(key: Key('room-tab-discussion'), text: 'Discussion'),
        Tab(key: Key('room-tab-vault'), text: 'Evidence'),
        Tab(key: Key('room-tab-timeline'), text: 'Timeline'),
        Tab(key: Key('room-tab-analysis'), text: 'Analysis'),
        Tab(key: Key('room-tab-map'), text: 'Connections'),
        Tab(key: Key('room-tab-tasks'), text: 'Tasks'),
        Tab(key: Key('room-tab-ai'), text: 'AI'),
        Tab(key: Key('room-tab-audit'), text: 'Audit Log'),
        Tab(key: Key('room-tab-members'), text: 'Members'),
        Tab(key: Key('room-tab-summary'), text: 'Summary'),
      ],
    );

    final tabViews = [
      DashboardScreen(roomId: widget.roomId),
      DiscussionPane(roomId: widget.roomId),
      VaultPane(roomId: widget.roomId),
      TimelinePane(roomId: widget.roomId),
      AnalysisPane(roomId: widget.roomId),
      ConnectionsScreen(roomId: widget.roomId),
      TasksPane(roomId: widget.roomId),
      AiPane(roomId: widget.roomId, caseType: widget.caseType),
      AuditPane(roomId: widget.roomId),
      _MembersPane(roomId: widget.roomId),
      SummaryPane(roomId: widget.roomId),
    ];

    if (!widget.embedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Case room'),
          actions: [
            if (canExport)
              IconButton(
                tooltip: 'Export case report',
                icon: const Icon(Icons.ios_share),
                onPressed: () => _export(context, ref),
              ),
          ],
          bottom: tabBar,
        ),
        body: TabBarView(controller: _tabs, children: tabViews),
      );
    }

    // Embedded v3 mode: room-head + tab strip + body, console-styled.
    return Column(
      children: [
        _RoomHead(
          roomId: widget.roomId,
          canExport: canExport,
          onExport: () => _export(context, ref),
        ),
        Container(color: Colors.transparent, child: tabBar),
        Expanded(
          child: TabBarView(controller: _tabs, children: tabViews),
        ),
      ],
    );
  }
}

/// v3 room-head: avatar chip + case name + #id + status pill + member
/// count + export action (v3 §7).
class _RoomHead extends ConsumerWidget {
  const _RoomHead({
    required this.roomId,
    required this.canExport,
    required this.onExport,
  });

  final String roomId;
  final bool canExport;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(roomsProvider);
    final members = ref.watch(roomMembersProvider(roomId));
    final text = Theme.of(context).textTheme;

    final room = roomsState is RoomsLoaded
        ? roomsState.rooms.where((r) => r.id == roomId).firstOrNull
        : null;
    final approvedCount = members.maybeWhen(
      data: (m) => m.length,
      orElse: () => 0,
    );

    final (statusColor, statusLabel) = room == null
        ? (AppColors.v3Info, 'LOADING')
        : switch (room.investigationStatus) {
            InvestigationStatus.open => (AppColors.statusOpen, 'Open'),
            InvestigationStatus.underInvestigation => (
              AppColors.v3Ok,
              'Under Investigation',
            ),
            InvestigationStatus.review => (AppColors.v3Warn, 'Review'),
            InvestigationStatus.closed => (AppColors.statusNeutral, 'Closed'),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.consoleBorder)),
      ),
      child: Row(
        children: [
          _roomAvatar(room?.name),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  room?.name ?? 'Case room',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '#${roomId.substring(0, roomId.length > 4 ? 4 : roomId.length)}',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.consoleMuted,
                        fontFamily: 'GeistMono',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusPill(color: statusColor, label: statusLabel),
                    const SizedBox(width: 8),
                    Text(
                      '$approvedCount investigators',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.consoleMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canExport)
            IconButton(
              tooltip: 'Export case report',
              icon: const Icon(Icons.ios_share, size: 18),
              color: AppColors.consoleMuted,
              onPressed: onExport,
            ),
        ],
      ),
    );
  }

  Widget _roomAvatar(String? name) {
    final initials = (name == null || name.isEmpty)
        ? 'CR'
        : name
              .split(' ')
              .take(2)
              .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
              .join();
    return Container(
      height: 40,
      width: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1), Color(0xFF7C3AED)],
        ),
        border: Border.all(color: const Color(0x26FFFFFF)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// v3 status pill — dot + label on tinted fill.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.color, required this.label});

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

class _MembersPane extends ConsumerWidget {
  const _MembersPane({required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(roomMembersProvider(roomId));
    final me = ref.watch(sessionProvider).value;
    final text = Theme.of(context).textTheme;

    return switch (members) {
      AsyncData(:final value) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(roomMembersProvider(roomId));
          await Future<void>.delayed(const Duration(milliseconds: 300));
        },
        child: ListView.builder(
          itemCount: value.length,
          itemBuilder: (context, index) => _MemberTile(
            member: value[index],
            isMe: value[index].userId == me?.id,
          ),
        ),
      ),
      AsyncError(:final error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            toAppException(error).message,
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.member, required this.isMe});

  final RoomMember member;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final status = member.status;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                (member.displayName ?? '?').substring(0, 1).toUpperCase(),
                style: text.headlineSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe
                        ? '${member.displayName ?? 'You'} (you)'
                        : member.displayName ?? 'Member',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${member.roleId} · ${status.name}',
                    style: text.bodyMedium?.copyWith(
                      color: text.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (status == MemberStatus.pending) ...[
              _iconButton(
                context,
                ref,
                icon: Icons.check,
                semantic: 'Approve member',
                approve: true,
              ),
              _iconButton(
                context,
                ref,
                icon: Icons.close,
                semantic: 'Deny member',
                approve: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconButton(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String semantic,
    required bool approve,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semantic,
      child: IconButton(
        icon: Icon(icon),
        color: approve ? scheme.primary : scheme.error,
        onPressed: () => _decide(context, ref, approve),
      ),
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    bool approve,
  ) async {
    try {
      final roomsRepository = ref.read(roomsRepositoryProvider);
      await roomsRepository.decideJoinRequest(
        roomId: member.roomId,
        memberId: member.id,
        approve: approve,
      );
      ref.invalidate(roomMembersProvider(member.roomId));
    } on AppException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}
