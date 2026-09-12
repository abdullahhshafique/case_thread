import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_providers.dart';
import 'discussion_pane.dart';
import 'tasks_pane.dart';
import 'timeline_pane.dart';
import 'vault_pane.dart';
import 'data/supabase_rooms_repository.dart' show roomsRepositoryProvider;
import 'rooms_providers.dart';

/// Room detail (Sprint 3–4): Vault tab (evidence) + Members tab
/// (owner controls: approve/deny, revoke). Timeline/discussion/tasks
/// arrive Sprint 5.
class RoomDetailScreen extends ConsumerStatefulWidget {
  const RoomDetailScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case room'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true, // five tabs need scroll room on mobile
          tabs: const [
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
              key: Key('room-tab-members'),
              icon: Icon(Icons.people_outline),
              text: 'Members',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          VaultPane(roomId: widget.roomId),
          TimelinePane(roomId: widget.roomId),
          DiscussionPane(roomId: widget.roomId),
          TasksPane(roomId: widget.roomId),
          _MembersPane(roomId: widget.roomId),
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
