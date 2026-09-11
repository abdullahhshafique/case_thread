import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/models.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/error_mapper.dart';
import '../../auth/auth_providers.dart';
import '../domain/rooms_repository.dart';

/// Supabase-backed [RoomsRepository]. Every privileged operation goes
/// through the 0007 security-definer RPCs; plain reads use PostgREST
/// under the 0005 RLS policies.
class SupabaseRoomsRepository implements RoomsRepository {
  SupabaseRoomsRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<CaseRoom>> getMyRooms() async {
    final rows = await _client
        .from('case_rooms')
        .select(
          'id, name, case_type, owner_id, status, created_at, code_rotated_at',
        )
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => CaseRoom.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<CreatedRoom> createRoom({
    required String name,
    required String caseTypeId,
  }) async {
    final result = await _guard(() async {
      final response = await _client.rpc(
        'create_case_room',
        params: {'room_name': name, 'type_id': caseTypeId},
      );
      return (response as Map<String, dynamic>);
    });
    return CreatedRoom(
      roomId: result['room_id'] as String,
      accessCode: result['access_code'] as String,
    );
  }

  @override
  Future<RoomPreview> previewRoomByCode(String code) async {
    final result = await _guard(() async {
      final response = await _client.rpc(
        'preview_room_by_code',
        params: {'code': code.trim().toUpperCase()},
      );
      // Single-row return arrives as a map; multi-row as a list.
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return Map<String, dynamic>.from(response as Map);
    });
    return RoomPreview(
      roomId: result['room_id'] as String,
      name: result['room_name'] as String,
      caseTypeId: result['case_type_id'] as String,
    );
  }

  @override
  Future<JoinRequestResult> requestJoin(String code, String roleId) async {
    final result = await _guard(() async {
      final response = await _client.rpc(
        'request_room_join',
        params: {'code': code.trim().toUpperCase(), 'requested_role': roleId},
      );
      if (response is List && response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
      return Map<String, dynamic>.from(response as Map);
    });
    return JoinRequestResult(
      memberId: result['member_id'] as String,
      status: result['status'] as String,
    );
  }

  @override
  Future<List<RoomMember>> getMembers(String roomId) async {
    final rows = await _client
        .from('room_members')
        .select(
          'id, room_id, user_id, role_id, status, requested_at, joined_at, '
          'profiles(display_name)',
        )
        .eq('room_id', roomId)
        .order('requested_at');

    return (rows as List)
        .map((row) => RoomMember.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<String> decideJoinRequest({
    required String roomId,
    required String memberId,
    required bool approve,
  }) async {
    return _guard(() async {
      final status = await _client.rpc(
        'decide_join_request',
        params: {
          'target_room': roomId,
          'target_member': memberId,
          'decision': approve ? 'approved' : 'revoked',
        },
      );
      return status as String;
    });
  }

  @override
  Future<String> rotateCode(String roomId) async {
    return _guard(() async {
      final code = await _client.rpc(
        'rotate_room_code',
        params: {'target_room': roomId},
      );
      return code as String;
    });
  }

  /// Maps PostgREST/RPC failures to typed exceptions (Rules.md §5) —
  /// matching on the message fragment our SQL raises.
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (error) {
      final message = error.toString();
      if (message.contains('Too many join attempts')) {
        throw const JoinRateLimitedException();
      }
      if (message.contains('Invalid or inactive room code')) {
        throw const InvalidRoomCodeException();
      }
      if (message.contains('not available for this case type')) {
        throw const RoleNotAllowedException();
      }
      if (message.contains('access to this room was revoked')) {
        throw const AccessRevokedException();
      }
      if (message.contains('Only the room owner')) {
        throw const NotRoomOwnerException();
      }
      throw toAppException(error);
    }
  }
}

final roomsRepositoryProvider = Provider<RoomsRepository>((ref) {
  return SupabaseRoomsRepository(ref.watch(supabaseClientProvider));
});
