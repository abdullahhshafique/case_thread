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
    required this.investigationStatus,
    required this.createdAt,
    this.codeRotatedAt,
    this.briefing,
  });

  final String id;
  final String name;
  final String caseType;
  final String ownerId;
  final String status;
  final InvestigationStatus investigationStatus;
  final DateTime createdAt;
  final DateTime? codeRotatedAt;

  /// Phase 2: optional case briefing (populated in Phase 6 via seed).
  final String? briefing;

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
      investigationStatus: switch (map['investigation_status'] as String?) {
        'under_investigation' => InvestigationStatus.underInvestigation,
        'review' => InvestigationStatus.review,
        'closed' => InvestigationStatus.closed,
        _ => InvestigationStatus.open,
      },
      createdAt: tryParse(map['created_at'] as String?) ?? DateTime.now(),
      codeRotatedAt: tryParse(map['code_rotated_at'] as String?),
      briefing: map['briefing'] as String?,
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

// ---------------------------------------------------------------------------
// Phase 5: Fact / Claim / Finding / Unknown classification
// (PRD §4.1). Applied to evidence_items, timeline_events,
// alibis, contradictions, investigation_gaps.
// ---------------------------------------------------------------------------
enum Classification { fact, claim, finding, unknown }

// ---------------------------------------------------------------------------
// Phase 5: Alibi verification status (PRD §4.2).
// ---------------------------------------------------------------------------
enum AlibiStatus { verified, partiallyVerified, conflict, insufficientData }

// ---------------------------------------------------------------------------
// Phase 5: Contradiction source type + status (PRD §4.3).
// ---------------------------------------------------------------------------
enum ContradictionSourceType { manual, aiSuggestion }

enum ContradictionStatus { open, resolved, dismissed }

// ---------------------------------------------------------------------------
// Phase 5: Investigation gap status (PRD §4.4).
// ---------------------------------------------------------------------------
enum GapStatus { open, inProgress, resolved }

// ---------------------------------------------------------------------------
// Phase 5: Investigation lifecycle (PRD §4.6).
// Additive to the existing CaseRoom.status (active/archived).
// Named distinctly in UI: "Investigation status" vs "Room status".
// ---------------------------------------------------------------------------
enum InvestigationStatus { open, underInvestigation, review, closed }

// ---------------------------------------------------------------------------
// Phase 5: Models
// ---------------------------------------------------------------------------

/// A claimed alibi for a person (entity), with verification
/// status and a required human-readable reason. Never a bare
/// status (PRD §4.2, Design.md §9 tone rules).
class Alibi {
  const Alibi({
    required this.id,
    required this.roomId,
    required this.entityId,
    required this.claimedWindowStart,
    required this.claimedWindowEnd,
    required this.claimText,
    required this.status,
    required this.statusReason,
    required this.createdAt,
    this.source,
    this.createdBy,
    this.verifiedBy,
    this.verifiedAt,
  });

  final String id;
  final String roomId;
  final String entityId;
  final DateTime claimedWindowStart;
  final DateTime claimedWindowEnd;
  final String claimText;
  final AlibiStatus status;
  final String statusReason;
  final DateTime createdAt;
  final String? source;
  final String? createdBy;
  final String? verifiedBy;
  final DateTime? verifiedAt;

  factory Alibi.fromMap(Map<String, dynamic> map) {
    return Alibi(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      entityId: map['entity_id'] as String? ?? '',
      claimedWindowStart: DateTime.parse(map['claimed_window_start'] as String),
      claimedWindowEnd: DateTime.parse(map['claimed_window_end'] as String),
      claimText: map['claim_text'] as String,
      status: switch (map['status'] as String?) {
        'verified' => AlibiStatus.verified,
        'partially_verified' => AlibiStatus.partiallyVerified,
        'conflict' => AlibiStatus.conflict,
        'insufficient_data' => AlibiStatus.insufficientData,
        _ => AlibiStatus.verified,
      },
      statusReason: map['status_reason'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      source: map['source'] as String?,
      createdBy: map['created_by'] as String?,
      verifiedBy: map['verified_by'] as String?,
      verifiedAt: map['verified_at'] == null
          ? null
          : DateTime.tryParse(map['verified_at'] as String),
    );
  }
}

/// A contradiction between two or more sources, reviewable and
/// resolvable independent of which agent (or human) raised it.
class Contradiction {
  const Contradiction({
    required this.id,
    required this.roomId,
    required this.sourceType,
    required this.conflictingDetail,
    required this.flaggedReason,
    required this.status,
    required this.createdAt,
    this.aiSuggestionId,
    this.relevantTime,
    this.relevantLocation,
    this.resolutionNote,
    this.flaggedBy,
    this.resolvedBy,
    this.resolvedAt,
    this.linkedTaskId,
  });

  final String id;
  final String roomId;
  final ContradictionSourceType sourceType;
  final String conflictingDetail;
  final String flaggedReason;
  final ContradictionStatus status;
  final DateTime createdAt;
  final String? aiSuggestionId;
  final DateTime? relevantTime;
  final String? relevantLocation;
  final String? resolutionNote;
  final String? flaggedBy;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? linkedTaskId;

  factory Contradiction.fromMap(Map<String, dynamic> map) {
    return Contradiction(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      sourceType: switch (map['source_type'] as String?) {
        'ai_suggestion' => ContradictionSourceType.aiSuggestion,
        _ => ContradictionSourceType.manual,
      },
      conflictingDetail: map['conflicting_detail'] as String,
      flaggedReason: map['flagged_reason'] as String,
      status: ContradictionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ContradictionStatus.open,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      aiSuggestionId: map['ai_suggestion_id'] as String?,
      relevantTime: map['relevant_time'] == null
          ? null
          : DateTime.tryParse(map['relevant_time'] as String),
      relevantLocation: map['relevant_location'] as String?,
      resolutionNote: map['resolution_note'] as String?,
      flaggedBy: map['flagged_by'] as String?,
      resolvedBy: map['resolved_by'] as String?,
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.tryParse(map['resolved_at'] as String),
      linkedTaskId: map['linked_task_id'] as String?,
    );
  }
}

/// A structured record of something the case has not yet
/// established (PRD §4.4 / §16 — the PDF's "major feature").
class InvestigationGap {
  const InvestigationGap({
    required this.id,
    required this.roomId,
    required this.gapType,
    required this.description,
    required this.status,
    required this.createdAt,
    this.sourceType,
    this.aiSuggestionId,
    this.linkedTaskId,
    this.createdBy,
    this.resolvedAt,
  });

  final String id;
  final String roomId;
  final String gapType;
  final String description;
  final GapStatus status;
  final DateTime createdAt;
  final ContradictionSourceType? sourceType;
  final String? aiSuggestionId;
  final String? linkedTaskId;
  final String? createdBy;
  final DateTime? resolvedAt;

  factory InvestigationGap.fromMap(Map<String, dynamic> map) {
    return InvestigationGap(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      gapType: map['gap_type'] as String? ?? 'unknown',
      description: map['description'] as String,
      status: switch (map['status'] as String?) {
        'in_progress' => GapStatus.inProgress,
        'resolved' => GapStatus.resolved,
        _ => GapStatus.open,
      },
      createdAt: DateTime.parse(map['created_at'] as String),
      sourceType: map['source_type'] == null
          ? null
          : switch (map['source_type'] as String) {
              'ai_suggestion' => ContradictionSourceType.aiSuggestion,
              _ => ContradictionSourceType.manual,
            },
      aiSuggestionId: map['ai_suggestion_id'] as String?,
      linkedTaskId: map['linked_task_id'] as String?,
      createdBy: map['created_by'] as String?,
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.tryParse(map['resolved_at'] as String),
    );
  }
}

/// Dashboard statistics from v_case_statistics view.
class CaseStatistics {
  const CaseStatistics({
    required this.roomId,
    required this.evidenceCount,
    required this.peopleCount,
    required this.locationsCount,
    required this.eventsCount,
    required this.contradictionsCount,
    required this.gapsCount,
    required this.unverifiedAlibisCount,
    required this.aiFindingsCount,
  });

  final String roomId;
  final int evidenceCount;
  final int peopleCount;
  final int locationsCount;
  final int eventsCount;
  final int contradictionsCount;
  final int gapsCount;
  final int unverifiedAlibisCount;
  final int aiFindingsCount;

  factory CaseStatistics.fromMap(Map<String, dynamic> map) {
    return CaseStatistics(
      roomId: map['room_id'] as String,
      evidenceCount: (map['evidence_count'] as num?)?.toInt() ?? 0,
      peopleCount: (map['people_count'] as num?)?.toInt() ?? 0,
      locationsCount: (map['locations_count'] as num?)?.toInt() ?? 0,
      eventsCount: (map['events_count'] as num?)?.toInt() ?? 0,
      contradictionsCount: (map['contradictions_count'] as num?)?.toInt() ?? 0,
      gapsCount: (map['gaps_count'] as num?)?.toInt() ?? 0,
      unverifiedAlibisCount:
          (map['unverified_alibis_count'] as num?)?.toInt() ?? 0,
      aiFindingsCount: (map['ai_findings_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Closed-case structured summary (PRD §4.6). Stable snapshot
/// stored as JSONB so it doesn't change if underlying data changes.
class CaseClosedSummary {
  const CaseClosedSummary({
    required this.id,
    required this.roomId,
    required this.summaryJson,
    required this.generatedAt,
    this.generatedBy,
  });

  final String id;
  final String roomId;
  final Map<String, dynamic> summaryJson;
  final DateTime generatedAt;
  final String? generatedBy;

  factory CaseClosedSummary.fromMap(Map<String, dynamic> map) {
    return CaseClosedSummary(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      summaryJson: map['summary_json'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['summary_json'] as Map)
          : {},
      generatedAt: DateTime.parse(map['generated_at'] as String),
      generatedBy: map['generated_by'] as String?,
    );
  }
}

/// Per-room breakdown for the dashboard graphs (Phase 6, doc §9):
/// evidence grouped by type + timeline events per day (14-day window).
class CaseBreakdown {
  const CaseBreakdown({
    required this.evidenceByType,
    required this.eventsPerDay,
  });

  /// e.g. {'pdf': 3, 'image': 1}
  final Map<String, int> evidenceByType;

  /// e.g. {'2026-09-15': 4, '2026-09-16': 2}
  final Map<String, int> eventsPerDay;

  factory CaseBreakdown.fromMap(Map<String, dynamic> map) {
    Map<String, int> readInts(Object? raw) {
      if (raw is! Map) return const {};
      return raw.map(
        (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
      );
    }

    return CaseBreakdown(
      evidenceByType: readInts(map['evidence_by_type']),
      eventsPerDay: readInts(map['events_per_day']),
    );
  }
}
