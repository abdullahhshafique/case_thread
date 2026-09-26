import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../offline/offline_providers.dart';
import 'rooms_providers.dart';
import 'data/supabase_room_content_repository.dart';
import 'domain/room_content_models.dart';
import '../../core/api/models.dart' show Permission;
import '../auth/auth_providers.dart' show sessionProvider;
import 'room_permissions.dart';
import 'discussion_flags.dart';

/// Discussion pane (Sprint 5): realtime thread with @mentions
/// (PRD §6.6). Posting is permission-gated by RLS; denied roles see a
/// read-only composer (their message bounces with a typed error).
class DiscussionPane extends ConsumerStatefulWidget {
  const DiscussionPane({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<DiscussionPane> createState() => _DiscussionPaneState();
}

class _DiscussionPaneState extends ConsumerState<DiscussionPane> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  /// True while the user is reading at (or near) the bottom — new
  /// messages auto-scroll. Scrolling up to read history unpins.
  bool _pinnedToBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final pos = _scrollController.position;
      final nearBottom = pos.maxScrollExtent - pos.pixels < 120;
      if (nearBottom != _pinnedToBottom) {
        setState(() => _pinnedToBottom = nearBottom);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(_discussionStreamProvider(widget.roomId));
    final canComment = ref
        .watch(myRoomPermissionsProvider(widget.roomId))
        .maybeWhen(data: (p) => p.can(Permission.comment), orElse: () => false);
    // Member identity: the realtime stream's rows carry no embed, so
    // author names resolve from the member list (works for live rows too).
    final members = ref.watch(roomMembersProvider(widget.roomId));
    final flags = ref.watch(discussionFlagsProvider(widget.roomId));
    final canEditCase = ref
        .watch(myRoomPermissionsProvider(widget.roomId))
        .maybeWhen(data: (p) => p.can(Permission.editCase), orElse: () => false);
    final nameByUser = members.maybeWhen(
      data: (m) => {for (final x in m) x.userId: x.displayName ?? ''},
      orElse: () => const <String, String>{},
    );
    // Members resolve lazily via membersNameMap() when sending.
    final text = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text(toAppException(error).message)),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet — start the discussion.',
                    style: text.bodyMedium,
                  ),
                );
              }
              // Discord order: oldest at top, newest at bottom, view
              // pinned to the bottom unless the user scrolled up to
              // read history. Sorted client-side — the realtime
              // snapshot order is not guaranteed.
              final ordered = [...list]
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              final pinned = ordered
                  .where((m) => flags.isPinned(m.id))
                  .toList(growable: false);
              if (_pinnedToBottom) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
              }
              // Phase 5: pinned messages stay in a compact strip at the
              // top; the main thread skips them (they're still in it —
              // the strip is a view, not a move).
              final body = ordered
                  .where((m) => !flags.isPinned(m.id))
                  .toList(growable: false);
              return Column(
                children: [
                  if (pinned.isNotEmpty)
                    _PinnedStrip(
                      pinned: pinned,
                      nameByUser: nameByUser,
                      flags: flags,
                      onUnpin: (id) => ref
                          .read(discussionFlagsProvider(widget.roomId).notifier)
                          .togglePin(id),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: body.length,
                      itemBuilder: (context, index) => _MessageTile(
                        message: body[index],
                        nameByUser: nameByUser,
                        currentUserId: ref.watch(sessionProvider).value?.id,
                        starred: flags.isStarred(body[index].id),
                        pinned: flags.isPinned(body[index].id),
                        onLongPress: () => _messageActions(body[index], canEditCase),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Tap-to-mention: inserts @DisplayName so the notification path
        // (PRD §6.6) triggers without guessing exact names.
        if (canComment)
          SizedBox(
            height: 36,
            child: members.maybeWhen(
              data: (m) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final member in m)
                    if (member.displayName != null)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ActionChip(
                          label: Text('@${member.displayName}'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _controller.text += '@${member.displayName} ',
                        ),
                      ),
                ],
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ),
        if (canComment)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('discussion-input'),
                      controller: _controller,
                      enabled: !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        labelText: 'Message', // persistent label (a11y)
                        hintText: 'Message the team (@ to mention)',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Semantics(
                    label: 'Send message',
                    child: IconButton.filled(
                      key: const Key('discussion-send'),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    // Resolve @mentions against member display names (PRD §6.6).
    final memberNames = membersNameMap();
    final mentionedNames = parseMentions(body, memberNames.keys.toList());

    setState(() => _sending = true);
    try {
      final mentionIds = mentionedNames
          .map((name) => memberNames[name]!)
          .toList();
      // Offline path: live insert; network failure queues the message
      // and the banner shows the queued count (policy §2 append-only
      // streams never conflict — replay is a plain insert).
      await runQueuedWrite(
        ref,
        widget.roomId,
        'post_message',
        {'body': body, 'mentions': mentionIds},
        () => ref
            .read(roomContentRepositoryProvider)
            .postMessage(
              roomId: widget.roomId,
              body: body,
              mentionUserIds: mentionIds,
            ),
      );
      _controller.clear();
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Phase 5: long-press actions — star, pin, extract-to-case.
  /// Star/pin are client-side view flags; extract writes a real manual
  /// timeline event (edit_case holders, 0005 policy).
  Future<void> _messageActions(DiscussionMessage message, bool canEditCase) async {
    final flags = ref.read(discussionFlagsProvider(widget.roomId).notifier);
    final starred = ref.read(discussionFlagsProvider(widget.roomId)).isStarred(message.id);
    final pinned = ref.read(discussionFlagsProvider(widget.roomId)).isPinned(message.id);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('msg-action-star'),
              leading: Icon(
                starred ? Icons.star : Icons.star_border,
                color: AppColors.statePending,
              ),
              title: Text(starred ? 'Remove star' : 'Star message'),
              onTap: () => Navigator.of(sheetContext).pop('star'),
            ),
            ListTile(
              key: const Key('msg-action-pin'),
              leading: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: AppColors.v3Info,
              ),
              title: Text(pinned ? 'Unpin' : 'Pin to top'),
              onTap: () => Navigator.of(sheetContext).pop('pin'),
            ),
            ListTile(
              key: const Key('msg-action-extract'),
              leading: Icon(
                Icons.playlist_add,
                color: canEditCase ? AppColors.stateSuccess : AppColors.consoleMuted,
              ),
              title: Text(
                canEditCase
                    ? 'Extract to case timeline'
                    : 'Extract to case timeline (needs edit permission)',
              ),
              enabled: canEditCase,
              onTap: () => Navigator.of(sheetContext).pop('extract'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'star':
        flags.toggleStar(message.id);
      case 'pin':
        flags.togglePin(message.id);
      case 'extract':
        await _extractToCase(message);
    }
  }

  /// Writes the message into the case timeline as a manual event,
  /// classified 'claim' (it is an unverified statement until an
  /// investigator confirms it — 0027 tone rules).
  Future<void> _extractToCase(DiscussionMessage message) async {
    final author = ref
        .read(roomMembersProvider(widget.roomId))
        .value
        ?.where((m) => m.userId == message.authorId)
        .firstOrNull
        ?.displayName ??
        message.authorName ??
        'Member';
    try {
      await ref
          .read(roomContentRepositoryProvider)
          .addManualEvent(
            roomId: widget.roomId,
            summary: 'Extracted from discussion ($author): ${message.body}',
            classification: 'claim',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to the case timeline.')),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  /// display name → user id for mention resolution.
  Map<String, String> membersNameMap() {
    final members = ref.read(roomMembersProvider(widget.roomId)).value ?? [];
    return {
      for (final m in members)
        if (m.displayName != null) m.displayName!: m.userId,
    };
  }
}

final _discussionStreamProvider =
    StreamProvider.family<List<DiscussionMessage>, String>((ref, roomId) {
      return ref.watch(roomContentRepositoryProvider).watchDiscussion(roomId);
    });

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    required this.message,
    required this.nameByUser,
    required this.currentUserId,
    this.starred = false,
    this.pinned = false,
    this.onLongPress,
  });

  final DiscussionMessage message;
  final Map<String, String> nameByUser;
  final String? currentUserId;
  final bool starred;
  final bool pinned;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = nameByUser[message.authorId] ?? message.authorName ?? 'Member';
    final isOwn = message.authorId == currentUserId;
    // v3 §8 chat bubbles: own messages anchor right on the teal fill,
    // others stay left on the card surface; avatar chip + timestamp.
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        constraints: const BoxConstraints(maxWidth: 560),
        child: Row(
          mainAxisAlignment: isOwn
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isOwn) ...[
              _AvatarChipMini(initials: _initialsOf(name)),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isOwn
                      ? AppColors.chatBubbleOwn
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(isOwn ? 14 : 4),
                    bottomRight: Radius.circular(isOwn ? 4 : 14),
                  ),
                  border: isOwn
                      ? null
                      : Border.all(color: AppColors.consoleBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isOwn) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: text.labelMedium?.copyWith(
                                color: AppColors.v3Info,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (pinned) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Icon(Icons.push_pin, size: 11, color: AppColors.v3Info),
                          ],
                          if (starred) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            Icon(Icons.star, size: 11, color: AppColors.statePending),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Text(
                      message.body,
                      style: text.bodyLarge?.copyWith(
                        color: isOwn ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _clock(message.createdAt),
                      style: text.labelSmall?.copyWith(
                        color: isOwn ? Colors.white70 : AppColors.consoleMuted,
                        fontFamily: 'GeistMono',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'CT';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  static String _clock(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final am = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }
}

/// Phase 5: compact strip of pinned messages above the thread. Tap a
/// chip to unpin; the message stays in the thread below.
class _PinnedStrip extends StatelessWidget {
  const _PinnedStrip({
    required this.pinned,
    required this.nameByUser,
    required this.flags,
    required this.onUnpin,
  });

  final List<DiscussionMessage> pinned;
  final Map<String, String> nameByUser;
  final DiscussionFlags flags;
  final ValueChanged<String> onUnpin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.consoleBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.push_pin, size: 12, color: AppColors.v3Info),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                'Pinned',
                style: text.labelMedium?.copyWith(
                  color: AppColors.v3Info,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          for (final message in pinned)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                key: Key('pinned-${message.id}'),
                children: [
                  Expanded(
                    child: Text(
                      '${nameByUser[message.authorId] ?? message.authorName ?? 'Member'}: '
                      '${message.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.consoleTextSecondary,
                      ),
                    ),
                  ),
                  if (flags.isStarred(message.id))
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xxs),
                      child: Icon(Icons.star, size: 12, color: AppColors.statePending),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Unpin',
                    icon: const Icon(Icons.close, size: 14),
                    color: AppColors.consoleMuted,
                    onPressed: () => onUnpin(message.id),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tiny v3 avatar chip (Design.md §1.5 palette — first tint).
class _AvatarChipMini extends StatelessWidget {
  const _AvatarChipMini({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      width: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.mintSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: AppColors.mintInk,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
