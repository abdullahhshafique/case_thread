import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';

/// Model parse contracts: if the Supabase wire shape changes, these fail
/// before any UI breaks (Architecture.md §2 API-contract driven).
void main() {
  group('RoleDefinition', () {
    test('parses permission grid with booleans', () {
      final role = RoleDefinition.fromMap({
        'id': 'analyst',
        'case_type': 'legal',
        'display_name': 'Analyst',
        'is_lead_tier': false,
        'permissions': {
          'view_case': true,
          'edit_case': true,
          'upload_evidence': true,
          'comment': true,
          'approve_ai_findings': false,
          'manage_members': false,
          'export_reports': false,
          'view_privileged': false,
        },
      });

      expect(role.has(Permission.viewCase), isTrue);
      expect(role.has(Permission.uploadEvidence), isTrue);
      expect(role.has(Permission.approveAiFindings), isFalse);
      expect(role.has(Permission.manageMembers), isFalse);
      expect(role.isLeadTier, isFalse);
    });

    test('missing permission keys default to deny', () {
      final role = RoleDefinition.fromMap({
        'id': 'observer',
        'case_type': 'legal',
        'display_name': 'Observer',
        'is_lead_tier': false,
        'permissions': {'view_case': true},
      });

      // Default deny mirrors RLS user_room_permission() semantics.
      expect(role.has(Permission.viewCase), isTrue);
      expect(role.has(Permission.comment), isFalse);
      expect(role.has(Permission.viewPrivileged), isFalse);
    });
  });

  group('CaseRoom', () {
    test('parses a full row', () {
      final room = CaseRoom.fromMap({
        'id': 'room-1',
        'name': 'Fraud Case 2026',
        'case_type': 'legal',
        'owner_id': 'user-1',
        'status': 'active',
        'created_at': '2026-09-10T12:00:00Z',
        'code_rotated_at': null,
      });

      expect(room.id, 'room-1');
      expect(room.name, 'Fraud Case 2026');
      expect(room.caseType, 'legal');
      expect(room.status, 'active');
      expect(room.codeRotatedAt, isNull);
    });

    test('throws typed error on malformed row', () {
      expect(
        () => CaseRoom.fromMap({'name': 'missing ids'}),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('RoomMember', () {
    test('parses statuses', () {
      final pending = RoomMember.fromMap({
        'id': 'm1',
        'room_id': 'room-1',
        'user_id': 'user-2',
        'role_id': 'analyst',
        'status': 'pending',
        'requested_at': '2026-09-10T12:00:00Z',
        'joined_at': null,
      });
      expect(pending.status, MemberStatus.pending);
      expect(pending.joinedAt, isNull);

      final approved = RoomMember.fromMap({
        'id': 'm2',
        'room_id': 'room-1',
        'user_id': 'user-2',
        'role_id': 'analyst',
        'status': 'approved',
        'requested_at': '2026-09-10T12:00:00Z',
        'joined_at': '2026-09-10T13:00:00Z',
      });
      expect(approved.status, MemberStatus.approved);
      expect(approved.joinedAt, isNotNull);
    });

    test('unknown status throws FormatException', () {
      expect(
        () => RoomMember.fromMap({
          'id': 'm3',
          'room_id': 'r',
          'user_id': 'u',
          'role_id': 'x',
          'status': 'banned',
          'requested_at': '2026-09-10T12:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('AuditLogEntry', () {
    test('parses and formats a summary', () {
      final entry = AuditLogEntry.fromMap({
        'id': 1,
        'room_id': 'room-1',
        'actor_id': 'user-1',
        'action_type': 'evidence_uploaded',
        'object_type': 'evidence_item',
        'object_id': 'ev-1',
        'metadata': {'filename': 'contract.pdf'},
        'created_at': '2026-09-10T12:00:00Z',
      });

      expect(entry.summary, 'evidence_uploaded · evidence_item');
      expect(entry.metadata['filename'], 'contract.pdf');
    });

    test('handles null actor (system events)', () {
      final entry = AuditLogEntry.fromMap({
        'id': 2,
        'room_id': 'room-1',
        'actor_id': null,
        'action_type': 'room_created',
        'object_type': 'case_room',
        'object_id': '',
        'metadata': {},
        'created_at': '2026-09-10T12:00:00Z',
      });

      expect(entry.actorId, isNull);
      expect(entry.objectId, '');
    });
  });

  group('Permission keys match the RLS grid', () {
    test('all eight dimensions present with correct keys', () {
      final expected = {
        'view_case',
        'edit_case',
        'upload_evidence',
        'comment',
        'approve_ai_findings',
        'manage_members',
        'export_reports',
        'view_privileged',
      };
      final keys = Permission.values.map((p) => p.key).toSet();
      expect(keys, expected);
    });
  });
}
