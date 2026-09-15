import 'dart:convert';

/// Sprint 5 models: timeline, discussion, tasks (Architecture.md §5).

/// One timeline entry — manual or system (0010 mirrors audit actions).
class TimelineEventModel {
  const TimelineEventModel({
    required this.id,
    required this.roomId,
    required this.eventType,
    required this.occurredAt,
    this.actorId,
    this.actorName,
    this.summary,
    this.actionType,
    this.details,
    this.conflictFlag = false,
  });

  final String id;
  final String roomId;

  /// 'manual' | 'system' | 'ai_suggestion' (last arrives Phase 3).
  final String eventType;

  /// Offline-sync LWW flag (0023): amber chip on the loser of a
  /// manual-event edit conflict.
  final bool conflictFlag;
  final String? actorId;
  final String? actorName;

  /// For system events: payload->summary (0010 mirror).
  final String? summary;

  /// For system events: payload->action_type (e.g. evidence_uploaded).
  final String? actionType;

  /// Raw payload details (JSONB) for expansion in the UI.
  final Map<String, dynamic>? details;

  final DateTime occurredAt;

  factory TimelineEventModel.fromMap(Map<String, dynamic> map) {
    final payload = map['payload'];
    Map<String, dynamic>? parsedPayload;
    if (payload is Map<String, dynamic>) {
      parsedPayload = payload;
    } else if (payload is String) {
      try {
        parsedPayload = Map<String, dynamic>.from(jsonDecode(payload) as Map);
      } on FormatException {
        parsedPayload = null;
      }
    }

    final actor = map['profiles'];
    return TimelineEventModel(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      eventType: map['event_type'] as String,
      actorId: map['actor_id'] as String?,
      actorName: actor is Map<String, dynamic>
          ? actor['display_name'] as String?
          : null,
      summary: parsedPayload?['summary'] as String?,
      actionType: parsedPayload?['action_type'] as String?,
      details: parsedPayload,
      conflictFlag: map['conflict_flag'] == true,
      occurredAt: DateTime.parse(map['occurred_at'] as String),
    );
  }

  /// Human line for the timeline list. System events carry their own
  /// summary; manual events render payload->summary (required client-side).
  String get displaySummary =>
      summary ??
      (eventType == 'manual'
          ? (details?['summary'] as String? ?? 'Case event')
          : 'Case activity');
}

/// A discussion message with @mentions (PRD §6.6).
class DiscussionMessage {
  const DiscussionMessage({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.parentMessageId,
    this.mentions = const [],
    this.authorName,
  });

  final String id;
  final String roomId;
  final String? parentMessageId;
  final String authorId;
  final String body;
  final List<String> mentions; // user ids
  final DateTime createdAt;
  final String? authorName;

  factory DiscussionMessage.fromMap(Map<String, dynamic> map) {
    final author = map['profiles'];
    final rawMentions = map['mentions'];
    return DiscussionMessage(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      parentMessageId: map['parent_message_id'] as String?,
      authorId: map['author_id'] as String,
      body: map['body'] as String,
      mentions: rawMentions is List ? List<String>.from(rawMentions) : const [],
      createdAt: DateTime.parse(map['created_at'] as String),
      authorName: author is Map<String, dynamic>
          ? author['display_name'] as String?
          : null,
    );
  }
}

/// A case task (PRD §6.6): title, assignee, optional due date, status.
class TaskModel {
  const TaskModel({
    required this.id,
    required this.roomId,
    required this.title,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.linkedEvidenceId,
    this.conflictFlag = false,
    this.conflictNote,
  });

  final String id;
  final String roomId;
  final String title;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;

  /// 'open' | 'in_progress' | 'done'.
  final String status;
  final String createdBy;
  final String? linkedEvidenceId;
  final DateTime createdAt;

  /// Offline-sync LWW metadata (0023): amber chip when the row lost a
  /// conflict; note explains who lost to what.
  final bool conflictFlag;
  final String? conflictNote;

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    final assignee = map['assignee'];
    return TaskModel(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      title: map['title'] as String,
      assigneeId: map['assignee_id'] as String?,
      assigneeName: assignee is Map<String, dynamic>
          ? assignee['display_name'] as String?
          : null,
      dueDate: map['due_date'] == null
          ? null
          : DateTime.tryParse(map['due_date'] as String),
      status: map['status'] as String,
      createdBy: map['created_by'] as String,
      linkedEvidenceId: map['linked_evidence_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      conflictFlag: map['conflict_flag'] == true,
      conflictNote: map['conflict_note'] as String?,
    );
  }

  bool get isDone => status == 'done';
}

/// Parses @mentions from message text into member-display-name tokens
/// (PRD §6.6: `@member` triggers a notification).
///
/// Matches `@Name` where Name is a member's display name (first name
/// or full name, case-insensitive). Returns the matched member ids.
List<String> parseMentions(String body, List<String> memberNames) {
  if (body.isEmpty || memberNames.isEmpty) return const [];
  final mentioned = <String>{};
  final lowerBody = body.toLowerCase();
  for (final name in memberNames) {
    final token = '@${name.toLowerCase()}';
    if (lowerBody.contains(token)) {
      mentioned.add(name);
    }
  }
  return mentioned.toList();
}
