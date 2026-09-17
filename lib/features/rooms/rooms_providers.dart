import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/api/supabase_case_type_repository.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';
import '../dashboard/dashboard_providers.dart';
import 'data/supabase_rooms_repository.dart';

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
