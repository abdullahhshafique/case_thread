import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/supabase_case_type_repository.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../alibis/alibi_providers.dart' show alibiListProvider;
import '../auth/auth_providers.dart';
import '../contradictions/contradiction_providers.dart'
    show contradictionListProvider;
import '../dashboard/dashboard_providers.dart';
import 'activity_feed.dart';
import 'data/supabase_room_content_repository.dart';
import 'data/supabase_rooms_repository.dart';
import 'domain/room_content_models.dart' show TaskModel;

/// Rooms list state machine.
sealed class RoomsState {
  const RoomsState();
}

final class RoomsLoading extends RoomsState {
  const RoomsLoading();
}

final class RoomsLoaded extends RoomsState {
  const RoomsLoaded(this.rooms);
  final List<CaseRoom> rooms;
}

final class RoomsError extends RoomsState {
  const RoomsError(this.error);
  final AppException error;
}

/// Loads the caller's rooms whenever the session changes.
final roomsProvider = NotifierProvider<RoomsController, RoomsState>(
  RoomsController.new,
);

class RoomsController extends Notifier<RoomsState> {
  @override
  RoomsState build() {
    // Re-load on every auth change (sign-in/out).
    ref.watch(sessionProvider);
    _load();
    return const RoomsLoading();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(roomsRepositoryProvider);
      final rooms = await repo.getMyRooms();
      state = RoomsLoaded(rooms);
    } on AppException catch (error) {
      state = RoomsError(error);
    } catch (error) {
      state = RoomsError(toAppException(error));
    }
  }

  Future<void> refresh() => _load();
}

/// Case types for the create-room flow.
final activeCaseTypesProvider = FutureProvider<List<CaseType>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(caseTypeRepositoryProvider).getActiveCaseTypes();
});

/// Roles for a case type (join-flow role picker, PRD §6.2).
final rolesForCaseTypeProvider =
    FutureProvider.family<List<RoleDefinition>, String>((ref, caseTypeId) {
      return ref
          .watch(caseTypeRepositoryProvider)
          .getRolesForCaseType(caseTypeId);
    });

/// Members of one room (room detail screen).
final roomMembersProvider = FutureProvider.family<List<RoomMember>, String>((
  ref,
  roomId,
) {
  ref.watch(sessionProvider);
  return ref.watch(roomsRepositoryProvider).getMembers(roomId);
});

/// Investigation statistics for one room
/// (Phase 5: v_case_statistics via dashboard provider).
final roomStatisticsProvider = FutureProvider.family<CaseStatistics, String>((
  ref,
  roomId,
) {
  ref.watch(sessionProvider);
  return ref.watch(dashboardRepositoryProvider).statistics(roomId);
});

/// Closed summary for one room (Phase 5).
final roomClosedSummaryProvider =
    FutureProvider.family<CaseClosedSummary?, String>((ref, roomId) {
      ref.watch(sessionProvider);
      return ref.watch(dashboardRepositoryProvider).closedSummary(roomId);
    });

/// Realtime task stream for one room (attention card open-task count).
final roomTasksStreamProvider = StreamProvider.family<List<TaskModel>, String>((
  ref,
  roomId,
) {
  return ref.watch(roomContentRepositoryProvider).watchTasks(roomId);
});

/// "Waiting on you" rollup for one room (v3 §6 attention card):
/// open tasks + open contradictions + alibis not yet verified. Every
/// number is real case data — the card renders zeros honestly.
class AttentionCounts {
  const AttentionCounts({
    required this.openTasks,
    required this.openContradictions,
    required this.alibisToVerify,
  });

  final int openTasks;
  final int openContradictions;
  final int alibisToVerify;

  bool get isClear =>
      openTasks == 0 && openContradictions == 0 && alibisToVerify == 0;

  /// '2 open tasks · 2 contradictions · 1 alibi to verify' — zero
  /// segments are omitted; a fully clear room gets the calm line.
  String get summary {
    final parts = <String>[
      if (openTasks > 0) '$openTasks open task${openTasks == 1 ? '' : 's'}',
      if (openContradictions > 0)
        '$openContradictions '
            'contradiction${openContradictions == 1 ? '' : 's'}',
      if (alibisToVerify > 0)
        '$alibisToVerify ali${alibisToVerify == 1 ? 'bus' : 'bis'} to verify',
    ];
    return parts.isEmpty
        ? 'All clear — nothing waiting on you.'
        : parts.join(' · ');
  }
}

final attentionCountsProvider = FutureProvider.family<AttentionCounts, String>((
  ref,
  roomId,
) async {
  ref.watch(sessionProvider);
  final tasks = await ref.watch(roomTasksStreamProvider(roomId).future);
  final contradictions = await ref.watch(
    contradictionListProvider(roomId).future,
  );
  final alibis = await ref.watch(alibiListProvider(roomId).future);
  return AttentionCounts(
    openTasks: tasks.where((t) => t.status != 'done').length,
    openContradictions: contradictions
        .where((c) => c.status == ContradictionStatus.open)
        .length,
    alibisToVerify: alibis
        .where((a) => a.status != AlibiStatus.verified)
        .length,
  );
});

/// Global unseen-activity feed (0014 v_activity_feed) — powers the
/// console notifications sheet and bell badge.
final activityFeedListProvider = FutureProvider<List<ActivityItem>>((ref) {
  ref.watch(sessionProvider);
  return ref.watch(activityFeedRepositoryProvider).getFeed();
});
