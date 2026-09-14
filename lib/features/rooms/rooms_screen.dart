import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart' show CaseRoom;
import '../../core/theme/app_spacing.dart';
import '../auth/auth_providers.dart';
import '../profiles/profiles_repository.dart';
import 'create_room_dialog.dart';
import 'domain/rooms_repository.dart' show CreatedRoom;
import 'rooms_providers.dart';

/// Authenticated home: the user's case rooms (Sprint 3 — real list).
class RoomsScreen extends ConsumerWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authName = ref.watch(sessionProvider).value?.displayName ?? '';
    final profile = ref.watch(myProfileProvider).value;
    final roomsState = ref.watch(roomsProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your case rooms'),
        actions: [
          IconButton(
            key: const Key('rooms-join'),
            tooltip: 'Join with a code', // a11y: labeled icon button.
            icon: const Icon(Icons.key_outlined),
            onPressed: () => context.push('/join'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                profile?.displayName ?? authName,
                style: text.bodyMedium?.copyWith(
                  color: text.bodyMedium?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('rooms-create'),
        onPressed: () => _openCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New room'),
      ),
      body: switch (roomsState) {
        RoomsLoading() => const Center(child: CircularProgressIndicator()),
        RoomsError(:final error) => _ErrorPane(
          message: error.message,
          onRetry: () => ref.read(roomsProvider.notifier).refresh(),
        ),
        RoomsLoaded(:final rooms) =>
          rooms.isEmpty
              ? _EmptyPane(onCreate: () => _openCreate(context, ref))
              : _RoomList(rooms: rooms),
      },
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<CreatedRoom>(
      context: context,
      builder: (_) => const CreateRoomDialog(),
    );
    if (created != null && context.mounted) {
      // Fresh list + navigate into the new room showing its code.
      ref.read(roomsProvider.notifier).refresh();
      if (context.mounted) context.push('/rooms/${created.roomId}');
    }
  }
}

class _RoomList extends StatelessWidget {
  const _RoomList({required this.rooms});

  final List<CaseRoom> rooms;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // Rules.md §9: lazy list — room counts grow unbounded.
      itemCount: rooms.length,
      itemBuilder: (context, index) {
        final room = rooms[index];
        return _RoomCard(room: room);
      },
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final CaseRoom room;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: InkWell(
        onTap: () => context.push('/rooms/${room.id}?type=${room.caseType}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: text.headlineSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${room.caseType} · ${room.status}',
                      style: text.bodyMedium?.copyWith(
                        color: text.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No case rooms yet', style: text.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Create a room for your case, or join one with a code.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              key: const Key('rooms-join-empty'),
              onPressed: () => context.push('/join'),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Join with a code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
