import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';
import 'package:case_thread/features/rooms/room_permissions.dart';

/// Sprint 6 permission-gating contracts: the UI hides what the RLS
/// would refuse; owner overrides are per the permission matrix draft.
void main() {
  group('RoomPermissions.can', () {
    test('reads the grid keys (Permission enum ↔ JSONB)', () {
      const perms = RoomPermissions(
        roleId: 'analyst',
        permissions: {
          'view_case': true,
          'edit_case': true,
          'upload_evidence': true,
          'comment': true,
          'approve_ai_findings': false,
          'manage_members': false,
          'export_reports': false,
          'view_privileged': false,
        },
      );

      expect(perms.can(Permission.viewCase), isTrue);
      expect(perms.can(Permission.uploadEvidence), isTrue);
      expect(perms.can(Permission.approveAiFindings), isFalse);
      expect(perms.can(Permission.manageMembers), isFalse);
    });

    test('missing keys default to deny (mirrors RLS semantics)', () {
      const perms = RoomPermissions(
        roleId: 'observer',
        permissions: {'view_case': true},
      );

      expect(perms.can(Permission.viewCase), isTrue);
      expect(perms.can(Permission.comment), isFalse);
      expect(perms.can(Permission.editCase), isFalse);
      expect(perms.can(Permission.viewPrivileged), isFalse);
    });

    test('owner overrides every permission (matrix draft: owner '
        'authority independent of role grid)', () {
      const owner = RoomPermissions(
        roleId: 'observer', // owner happens to hold a minimal role
        isOwner: true,
        permissions: {'view_case': true},
      );

      // The owner can do anything the UI gates on, regardless of grid.
      expect(owner.can(Permission.uploadEvidence), isTrue);
      expect(owner.can(Permission.manageMembers), isTrue);
      expect(owner.can(Permission.exportReports), isTrue);
    });

    test('empty permissions represent a non-member read-only state', () {
      const empty = RoomPermissions.empty;
      expect(empty.roleId, isNull);
      expect(empty.isOwner, isFalse);
      expect(empty.can(Permission.viewCase), isFalse);
    });
  });
}
