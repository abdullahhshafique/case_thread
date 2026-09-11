import '../../../core/api/models.dart';
import '../../../core/errors/app_exceptions.dart';

/// Room-service results mirroring the 0007 RPC contracts.

/// Returned once by create — the plaintext code never persists client-side
/// beyond showing it to the owner (PRD §6.1).
class CreatedRoom {
  const CreatedRoom({required this.roomId, required this.accessCode});
  final String roomId;
  final String accessCode;
}

/// What preview_room_by_code reveals before joining (PRD §6.2).
class RoomPreview {
  const RoomPreview({
    required this.roomId,
    required this.name,
    required this.caseTypeId,
  });
  final String roomId;
  final String name;
  final String caseTypeId;
}

/// Result of a join request submission.
class JoinRequestResult {
  const JoinRequestResult({required this.memberId, required this.status});

  /// 'pending' (awaiting owner), 'approved' (existing member re-join
  /// routed straight in — PRD §6.2 edge case).
  final String status;
  final String memberId;
}

/// Rooms contract (Sprint 3): all operations run through the 0007
/// security-definer RPCs — the client never touches code hashes or
/// audit rows directly (Rules.md §10 client trust boundary).
abstract class RoomsRepository {
  /// Rooms the caller belongs to (any status), newest first.
  Future<List<CaseRoom>> getMyRooms();

  /// Creates a room; caller becomes owner with the case type's
  /// owner-default role. Returns the plaintext access code ONCE.
  Future<CreatedRoom> createRoom({
    required String name,
    required String caseTypeId,
  });

  /// Validates a code and returns the room's name/case type for the
  /// role-picking step. Throws [InvalidRoomCodeException] — with no
  /// information about whether the code ever existed (PRD §6.2).
  Future<RoomPreview> previewRoomByCode(String code);

  /// Submits (or re-submits) a join request for the room behind `code`.
  Future<JoinRequestResult> requestJoin(String code, String roleId);

  /// Members of a room the caller can see (approved co-members plus the
  /// caller's own row — RLS scoped, see 0005/0007 policies).
  Future<List<RoomMember>> getMembers(String roomId);

  /// Owner-only: approve or revoke a member. Returns the new status.
  Future<String> decideJoinRequest({
    required String roomId,
    required String memberId,
    required bool approve,
  });

  /// Owner-only: rotate the access code. Old code invalid for new joins
  /// immediately; pending requests stay valid (PRD §6.1). Returns the
  /// new plaintext code ONCE.
  Future<String> rotateCode(String roomId);
}
