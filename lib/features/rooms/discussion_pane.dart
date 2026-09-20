import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/theme/app_spacing.dart';
import '../offline/offline_providers.dart';
import 'rooms_providers.dart';
import 'data/supabase_room_content_repository.dart';
import 'domain/room_content_models.dart';
import '../../core/api/models.dart' show Permission;
import 'room_permissions.dart';

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
              if (_pinnedToBottom) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: ordered.length,
                itemBuilder: (context, index) => _MessageTile(
                  message: ordered[index],
                  nameByUser: nameByUser,
                ),
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
  const _MessageTile({required this.message, required this.nameByUser});

  final DiscussionMessage message;
  final Map<String, String> nameByUser;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nameByUser[message.authorId] ?? message.authorName ?? 'Member',
              style: text.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(message.body, style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}
