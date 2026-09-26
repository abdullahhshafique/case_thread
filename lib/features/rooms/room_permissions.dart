import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../auth/auth_providers.dart';

/// When non-null, overrides the live Supabase permission resolution
/// for debug/testing only (PRD §Phase 1). The value is a permission
/// grid — e.g. {'canEditEvidence': true, 'canDeleteComment': false}.
/// Use any key; unlisted keys default to false unless isOwner is true.
/// Debug-only override: non-null = demo mode with these permissions.
/// Use demoRoleOverrideProvider.notifier.state = {...} to set.
final demoRoleOverrideProvider =
    NotifierProvider<_DemoRoleNotifier, Map<String, bool>?>(
      _DemoRoleNotifier.new,
    );

class _DemoRoleNotifier extends Notifier<Map<String, bool>?> {
  @override
  Map<String, bool>? build() => null;

  void set(Map<String, bool> perms) => state = perms;
  void clear() => state = null;
}

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

      if (kDebugMode) {
        final override = ref.read(demoRoleOverrideProvider);
        if (override != null) {
          return RoomPermissions(
            roleId: 'demo',
            isOwner: true,
            permissions: override,
          );
        }
      }
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
