import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_providers.dart';
import '../offline/offline_banner.dart';
import 'activity_feed.dart';
import 'ai_pane.dart';
import 'export_report.dart';
import 'discussion_pane.dart';
import 'tasks_pane.dart';
import 'timeline_pane.dart';
import 'vault_pane.dart';
import 'analysis_pane.dart';
import '../dashboard/dashboard_screen.dart';
import '../connections/connections_screen.dart';
import 'data/supabase_rooms_repository.dart' show roomsRepositoryProvider;
import 'rooms_providers.dart';

/// Room detail (Sprint 3–4): Vault tab (evidence) + Members tab
/// (owner controls: approve/deny, revoke). Timeline/discussion/tasks
/// arrive Sprint 5. Analysis tab (alibis, contradictions, gaps) +
/// Quick Actions bar added Phase 5.
class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.caseType,
  });

  final String roomId;
  final String caseType;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 9, vsync: this);

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
      // Copy-to-clipboard is the universal "save it somewhere" on all
      // our platforms for now (Phase 4 adds platform file dialogs).
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

  /// Quick Actions bar (Phase 5): one-swipe access to the most
  /// common investigation tasks (PRD §2.1 / §2.3).
  Widget _quickActions() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in _quickActionDefs)
            _QuickAction(
              key: Key(action.key),
              icon: action.icon,
              label: action.label,
              onTap: () => _tabs.index = action.tabIndex,
            ),
        ],
      ),
    );
  }

  List<_QuickActionDef> get _quickActionDefs => const [
    _QuickActionDef(
      key: 'qa-dashboard',
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      tabIndex: 0,
    ),
    _QuickActionDef(
      key: 'qa-evidence',
      icon: Icons.cloud_upload,
      label: 'Evidence',
      tabIndex: 1,
    ),
    _QuickActionDef(
      key: 'qa-event',
      icon: Icons.timeline,
      label: 'Event',
      tabIndex: 2,
    ),
    _QuickActionDef(
      key: 'qa-statement',
      icon: Icons.note,
      label: 'Statement',
      tabIndex: 3,
    ),
    _QuickActionDef(
      key: 'qa-task',
      icon: Icons.add_task,
      label: 'Task',
      tabIndex: 4,
    ),
    _QuickActionDef(
      key: 'qa-person',
      icon: Icons.person_add,
      label: 'Person',
      tabIndex: 6,
    ),
    _QuickActionDef(
      key: 'qa-map',
      icon: Icons.hub_outlined,
      label: 'Map',
      tabIndex: 7,
    ),
    _QuickActionDef(
      key: 'qa-alibi',
      icon: Icons.shield,
      label: 'Alibi',
      tabIndex: 8,
    ),
    _QuickActionDef(
      key: 'qa-contradiction',
      icon: Icons.flag,
      label: 'Contradiction',
      tabIndex: 8,
    ),
    _QuickActionDef(
      key: 'qa-gap',
      icon: Icons.report_problem_outlined,
      label: 'Gap',
      tabIndex: 8,
    ),
  ];

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Case room'),
        actions: [
          if (canExport)
            IconButton(
              tooltip: 'Export case report', // a11y: labeled icon button
              icon: const Icon(Icons.ios_share),
              onPressed: () => _export(context, ref),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true, // five tabs need scroll room on mobile
          tabs: const [
            Tab(
              key: Key('room-tab-dashboard'),
              icon: Icon(Icons.dashboard_outlined),
              text: 'Dashboard',
            ),
            Tab(
              key: Key('room-tab-vault'),
              icon: Icon(Icons.folder_outlined),
              text: 'Vault',
            ),
            Tab(
              key: Key('room-tab-timeline'),
              icon: Icon(Icons.timeline),
              text: 'Timeline',
            ),
            Tab(
              key: Key('room-tab-discussion'),
              icon: Icon(Icons.forum_outlined),
              text: 'Discussion',
            ),
            Tab(
              key: Key('room-tab-tasks'),
              icon: Icon(Icons.checklist),
              text: 'Tasks',
            ),
            Tab(
              key: Key('room-tab-ai'),
              icon: Icon(Icons.auto_awesome_outlined),
              text: 'AI',
            ),
            Tab(
              key: Key('room-tab-members'),
              icon: Icon(Icons.people_outline),
              text: 'Members',
            ),
            Tab(
              key: Key('room-tab-map'),
              icon: Icon(Icons.hub_outlined),
              text: 'Map',
            ),
            Tab(
              key: Key('room-tab-analysis'),
              icon: Icon(Icons.analytics),
              text: 'Analysis',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Offline banner (policy §2: stale-until-confirmed reads with
          // a visible "as of" watermark; hidden when online).
          const OfflineBanner(),
          // Quick Actions bar (Phase 5: one-swipe access to the most
          // common investigation tasks — PRD §2.1/§2.3).
          _quickActions(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                DashboardScreen(roomId: widget.roomId),
                VaultPane(roomId: widget.roomId),
                TimelinePane(roomId: widget.roomId),
                DiscussionPane(roomId: widget.roomId),
                TasksPane(roomId: widget.roomId),
                AiPane(roomId: widget.roomId, caseType: widget.caseType),
                _MembersPane(roomId: widget.roomId),
                ConnectionsScreen(roomId: widget.roomId),
                AnalysisPane(roomId: widget.roomId),
              ],
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
      await ref
          .read(roomsRepositoryProvider)
          .decideJoinRequest(
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

/// Descriptor for a single quick-action chip.
class _QuickActionDef {
  const _QuickActionDef({
    required this.key,
    required this.icon,
    required this.label,
    required this.tabIndex,
  });

  final String key;
  final IconData icon;
  final String label;
  final int tabIndex;
}

/// One pill-shaped quick action chip (Design.md §1 — amber
/// reserved for pending AI only; chips use primary).
class _QuickAction extends StatelessWidget {
  const _QuickAction({
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
