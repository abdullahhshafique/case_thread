import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../auth/auth_providers.dart';

/// The caller's effective permissions in one room — resolved from
/// their membership role's config grid (0004) by joining
/// room_members → roles. Used by the UI to hide actions the RLS
/// would refuse anyway (Architecture.md §2: UI hides, DB refuses).
class RoomPermissions {
  const RoomPermissions({
    this.roleId,
    this.isOwner = false,
    this.permissions = const {},
  });

  /// Null when the caller has no approved membership in the room.
  final String? roleId;
  final bool isOwner;
  final Map<String, bool> permissions;

  bool can(Permission key) => isOwner || (permissions[key.key] ?? false);

  static const empty = RoomPermissions();
}

/// Resolves the caller's role + permission grid for [roomId] via a
/// single PostgREST embed (room_members → roles, filtered to self).
final myRoomPermissionsProvider =
    FutureProvider.family<RoomPermissions, String>((ref, roomId) async {
      final client = ref.watch(supabaseClientProvider);
      final me = ref.watch(sessionProvider).value?.id;
      if (me == null) return RoomPermissions.empty;

      // Owner check: the room row itself (visible to owner + members).
      final rooms = await client
          .from('case_rooms')
          .select('owner_id')
          .eq('id', roomId)
          .maybeSingle();
      final isOwner = rooms != null && rooms['owner_id'] == me;

      // Membership row with the role grid embedded.
      final rows = await client
          .from('room_members')
          .select('role_id, status, roles(permissions)')
          .eq('room_id', roomId)
          .eq('user_id', me)
          .eq('status', 'approved')
          .maybeSingle();

      if (rows == null) {
        return RoomPermissions(isOwner: isOwner);
      }
      final role = rows['roles'];
      final grid = role is Map<String, dynamic>
          ? Map<String, bool>.from(
              (role['permissions'] as Map).map(
                (k, v) => MapEntry(k as String, v == true),
              ),
            )
          : <String, bool>{};

      return RoomPermissions(
        roleId: rows['role_id'] as String?,
        isOwner: isOwner,
        permissions: grid,
      );
    });
