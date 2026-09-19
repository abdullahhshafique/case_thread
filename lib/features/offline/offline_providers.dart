import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exceptions.dart';

import '../auth/auth_providers.dart';
import 'offline_queue.dart';
import 'offline_sync.dart';

/// Offline providers: queue depth for badges, sync controller for the
/// write paths, connectivity state for the banner.
///
/// Connectivity: no plugin dependency (Rules.md §4) — the FIRST failed
/// network call flips us offline; a successful call flips us back and
/// triggers replay. The banner says "offline — as of" (policy §2 reads:
/// stale-until-confirmed).

/// Whether the app currently believes it's offline.
final isOfflineProvider = NotifierProvider<IsOfflineNotifier, bool>(
  IsOfflineNotifier.new,
);

class IsOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// When the app last confirmed fresh data (for the banner watermark).
final lastSyncedAtProvider = NotifierProvider<LastSyncedAtNotifier, DateTime?>(
  LastSyncedAtNotifier.new,
);

class LastSyncedAtNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime? value) => state = value;
}

/// Live queue depth (drives badges + the banner count).
final offlineQueueDepthProvider = NotifierProvider<QueueDepthNotifier, int>(
  QueueDepthNotifier.new,
);

class QueueDepthNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

/// The sync controller, wired to the real client + store.
final offlineSyncProvider = Provider<OfflineSync>((ref) {
  final sync = OfflineSync(
    store: SharedPreferencesOfflineQueueStore(),
    client: ref.watch(supabaseClientProvider),
  );
  ref.keepAlive();
  return sync;
});

/// Wraps a pane write: try live through [liveWrite]; on network failure
/// flip the offline flag (the mutation is queued inside) and rethrow so
/// the UI can show its queued/offline state. On success, mark online
/// and replay the queue if we were offline (policy §3).
///
/// Widget-facing: every call site is a pane holding [WidgetRef], which
/// reads providers exactly like [Ref].
Future<bool> runQueuedWrite(
  WidgetRef ref,
  String roomId,
  String kind,
  Map<String, dynamic> params,
  Future<void> Function() liveWrite,
) async {
  final sync = ref.read(offlineSyncProvider);
  final wasOffline = ref.read(isOfflineProvider);
  try {
    final landed = await sync.run(roomId, kind, params, liveWrite);
    ref.read(isOfflineProvider.notifier).set(false);
    ref.read(lastSyncedAtProvider.notifier).set(DateTime.now());
    unawaited(refreshQueueDepth(ref.read(offlineQueueDepthProvider.notifier)));
    if (wasOffline) {
      // A live write proves connectivity — drain the queue now.
      unawaited(maybeReplay(ref));
    }
    return landed;
  } on AppException catch (error) {
    if (error is NetworkException) {
      ref.read(isOfflineProvider.notifier).set(true);
      unawaited(
        refreshQueueDepth(ref.read(offlineQueueDepthProvider.notifier)),
      );
    }
    rethrow; // typed; the pane shows the specific message
  }
}

/// Marks the app offline (a read path failed on network).
void markOffline(WidgetRef ref) {
  ref.read(isOfflineProvider.notifier).set(true);
  unawaited(refreshQueueDepth(ref.read(offlineQueueDepthProvider.notifier)));
}

/// Replays the queue if the offline flag is set (called after any
/// successful network call). Returns null when there was nothing to do
/// or the replay hit the network again — next success retries.
Future<ReplayReport?> maybeReplay(WidgetRef ref) async {
  if (!ref.read(isOfflineProvider)) return null;
  try {
    final report = await ref.read(offlineSyncProvider).replay();
    ref.read(isOfflineProvider.notifier).set(false);
    ref.read(lastSyncedAtProvider.notifier).set(DateTime.now());
    unawaited(refreshQueueDepth(ref.read(offlineQueueDepthProvider.notifier)));
    return report;
  } on Exception {
    return null; // still offline; next success retries
  }
}

/// Loads the queue and pushes its size into the depth notifier.
Future<void> refreshQueueDepth(QueueDepthNotifier notifier) async {
  try {
    final queue = await SharedPreferencesOfflineQueueStore().load();
    notifier.set(queue.length);
  } on Exception {
    // Depth is cosmetic; never let it break a write path.
  }
}
