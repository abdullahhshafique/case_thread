import 'dart:convert';

import '../errors/app_exceptions.dart';

/// Typed models for the CaseThread schema (Architecture.md §5).
///
/// These are the client-side contracts every repository parses into —
/// no raw `Map<String, dynamic>` beyond the data layer (Architecture.md §2:
/// API-contract driven, no ad-hoc query strings in UI code).

/// A case type definition — domain modules are data, not code.
class CaseType {
  const CaseType({
    required this.id,
    required this.displayName,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String displayName;
  final String description;
  final bool isActive;

  factory CaseType.fromMap(Map<String, dynamic> map) {
    return CaseType(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      description: (map['description'] as String?) ?? '',
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }
}

/// A role definition within a case type, with its permission grid
/// (keys per docs/permission-matrix-draft.md §1).
class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.caseType,
    required this.displayName,
    required this.isLeadTier,
    required this.permissions,
  });

  final String id;
  final String caseType;
  final String displayName;
  final bool isLeadTier;
  final Map<String, bool> permissions;

  factory RoleDefinition.fromMap(Map<String, dynamic> map) {
    final rawPerms = map['permissions'];
    final permissions = <String, bool>{};
    if (rawPerms is Map<String, dynamic>) {
      for (final entry in rawPerms.entries) {
        permissions[entry.key] = entry.value == true;
      }
    }
    return RoleDefinition(
      id: map['id'] as String,
      caseType: map['case_type'] as String,
      displayName: map['display_name'] as String,
      isLeadTier: (map['is_lead_tier'] as bool?) ?? false,
      permissions: permissions,
    );
  }

  /// Reads a permission key; missing keys are false by design (default
  /// deny — mirrors the RLS `user_room_permission()` behaviour).
  bool has(Permission permission) => permissions[permission.key] ?? false;
}

/// The eight permission dimensions (PRD §6.3, draft matrix §1).
enum Permission {
  viewCase('view_case'),
  editCase('edit_case'),
  uploadEvidence('upload_evidence'),
  comment('comment'),
  approveAiFindings('approve_ai_findings'),
  manageMembers('manage_members'),
  exportReports('export_reports'),
  viewPrivileged('view_privileged');

  const Permission(this.key);

  /// The JSONB key used in the roles grid and RLS policies.
  final String key;
}

/// A case room as the client sees it. `accessCodeHash` never leaves the
/// server through any client path — kept private for completeness of the
/// row shape, but repositories must not expose it in UI-facing models.
class CaseRoom {
  const CaseRoom({
    required this.id,
    required this.name,
    required this.caseType,
    required this.ownerId,
    required this.status,
    required this.createdAt,
    this.codeRotatedAt,
  });

  final String id;
  final String name;
  final String caseType;
  final String ownerId;
  final String status;
  final DateTime createdAt;
  final DateTime? codeRotatedAt;

  factory CaseRoom.fromMap(Map<String, dynamic> map) {
    DateTime? tryParse(String? iso) =>
        iso == null ? null : DateTime.tryParse(iso);

    if (map['id'] == null || map['name'] == null || map['case_type'] == null) {
      throw const UnexpectedException(
        message: 'Malformed case room row received from the server.',
      );
    }
    return CaseRoom(
      id: map['id'] as String,
      name: map['name'] as String,
      caseType: map['case_type'] as String,
      ownerId: map['owner_id'] as String,
      status: (map['status'] as String?) ?? 'active',
      createdAt: tryParse(map['created_at'] as String?) ?? DateTime.now(),
      codeRotatedAt: tryParse(map['code_rotated_at'] as String?),
    );
  }
}

/// Membership row: user ↔ room with role and approval status.
class RoomMember {
  const RoomMember({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.roleId,
    required this.status,
    required this.requestedAt,
    this.joinedAt,
    this.displayName,
  });

  final String id;
  final String roomId;
  final String userId;
  final String roleId;
  final MemberStatus status;
  final DateTime requestedAt;
  final DateTime? joinedAt;

  /// Joined from profiles when the member-list query includes it.
  final String? displayName;

  factory RoomMember.fromMap(Map<String, dynamic> map) {
    return RoomMember(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      userId: map['user_id'] as String,
      roleId: map['role_id'] as String,
      status: MemberStatus.fromName(map['status'] as String),
      requestedAt: DateTime.parse(map['requested_at'] as String),
      joinedAt: map['joined_at'] == null
          ? null
          : DateTime.parse(map['joined_at'] as String),
      displayName: map['profiles'] is Map<String, dynamic>
          ? (map['profiles'] as Map<String, dynamic>)['display_name'] as String?
          : map['display_name'] as String?,
    );
  }
}

enum MemberStatus {
  pending,
  approved,
  revoked;

  static MemberStatus fromName(String name) => switch (name) {
    'pending' => MemberStatus.pending,
    'approved' => MemberStatus.approved,
    'revoked' => MemberStatus.revoked,
    _ => throw FormatException('Unknown member status: $name'),
  };
}

/// Audit-log entry (immutable by construction — no edit methods exist).
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.roomId,
    required this.actionType,
    required this.objectType,
    required this.createdAt,
    this.actorId,
    this.objectId = '',
    this.metadata = const {},
  });

  final int id;
  final String roomId;
  final String? actorId;
  final String actionType;
  final String objectType;
  final String objectId;
  final DateTime createdAt;
  final Map<String, dynamic> metadata;

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    return AuditLogEntry(
      id: map['id'] as int,
      roomId: map['room_id'] as String,
      actorId: map['actor_id'] as String?,
      actionType: map['action_type'] as String,
      objectType: map['object_type'] as String,
      objectId: (map['object_id'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      metadata: map['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(
              jsonDecode(jsonEncode(map['metadata'])) as Map,
            )
          : const {},
    );
  }
}

/// E2E parse-ability guard for the monospace audit UI (JetBrains Mono
/// renders these — Design.md §2).
extension AuditLogEntryFormatting on AuditLogEntry {
  /// Stable `action_type object_type` summary for list rows.
  String get summary => '$actionType · $objectType';
}
