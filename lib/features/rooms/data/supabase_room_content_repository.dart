import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/errors/error_mapper.dart';
import '../../auth/auth_providers.dart';
import '../domain/room_content_models.dart';

/// Sprint 5 content contract: timeline reads, threaded discussion with
/// realtime + @mentions, task CRUD. All writes go through PostgREST
/// under the 0005 permission-key policies; audit/mirrors are DB
/// triggers (0010) — the client never writes audit rows.
abstract class RoomContentRepository {
  /// Merged manual + system timeline, newest first.
  Future<List<TimelineEventModel>> getTimeline(String roomId);

  /// Realtime timeline stream (architecture.md §8 — Riverpod wraps
  /// Supabase Realtime; channels effectively room-scoped via filters).
  Stream<List<TimelineEventModel>> watchTimeline(String roomId);

  /// Realtime discussion stream, newest last.
  Stream<List<DiscussionMessage>> watchDiscussion(String roomId);

  /// Posts a message; mentions resolved from member names by the
  /// caller (UI) and stored as user ids (PRD §6.6).
  Future<void> postMessage({
    required String roomId,
    required String body,
    String? parentMessageId,
    List<String> mentionUserIds = const [],
  });

  /// Room tasks by status groups.
  Future<List<TaskModel>> getTasks(String roomId);

  /// Realtime task stream.
  Stream<List<TaskModel>> watchTasks(String roomId);

  /// Creates a task (caller needs edit_case — policy enforced).
  Future<void> createTask({
    required String roomId,
    required String title,
    String? assigneeId,
    DateTime? dueDate,
  });

  /// Updates status; assignee may tick done, permitted roles may edit
  /// (0005 policy enforces the boundary).
  Future<void> updateTaskStatus({
    required String roomId,
    required String taskId,
    required String status,
  });
}

class SupabaseRoomContentRepository implements RoomContentRepository {
  SupabaseRoomContentRepository(this._client);

  final supabase.SupabaseClient _client;

  static const _timelineSelect =
      'id, room_id, event_type, actor_id, occurred_at, payload, '
      'profiles(actor_id)(display_name)';

  @override
  Future<List<TimelineEventModel>> getTimeline(String roomId) async {
    // 0013: reads go through the redacted view — privileged payload
    // fields never reach clients lacking view_privileged.
    final rows = await _client
        .from('v_timeline')
        .select(_timelineSelect)
        .eq('room_id', roomId)
        .order('occurred_at', ascending: false)
        .limit(200); // Rules.md §9: bound list queries
    return _rowsToTimeline(rows as List);
  }

  @override
  Stream<List<TimelineEventModel>> watchTimeline(String roomId) {
    return _client
        .from('v_timeline')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('occurred_at')
        .map(_rowsToTimeline);
  }

  List<TimelineEventModel> _rowsToTimeline(List rows) {
    return rows
        .map(
          (row) => TimelineEventModel.fromMap(Map<String, dynamic>.from(row)),
        )
        .toList()
        .reversed
        .toList(); // newest first in UI
  }

  @override
  Stream<List<DiscussionMessage>> watchDiscussion(String roomId) {
    return _client
        .from('discussion_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map(
          (rows) => rows
              .map(
                (row) =>
                    DiscussionMessage.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList(),
        );
  }

  @override
  Future<void> postMessage({
    required String roomId,
    required String body,
    String? parentMessageId,
    List<String> mentionUserIds = const [],
  }) async {
    try {
      await _client.from('discussion_messages').insert({
        'room_id': roomId,
        'author_id': _client.auth.currentUser!.id,
        'body': body,
        'parent_message_id': parentMessageId,
        'mentions': mentionUserIds,
      });
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<List<TaskModel>> getTasks(String roomId) async {
    final rows = await _client
        .from('tasks')
        .select(
          'id, room_id, title, assignee_id, assignee:profiles(assignee_id)(display_name), '
          'due_date, status, created_by, linked_evidence_id, created_at',
        )
        .eq('room_id', roomId)
        .order('created_at');
    return _rowsToTasks(rows as List);
  }

  @override
  Stream<List<TaskModel>> watchTasks(String roomId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map(_rowsToTasks);
  }

  List<TaskModel> _rowsToTasks(List rows) {
    return rows
        .map((row) => TaskModel.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> createTask({
    required String roomId,
    required String title,
    String? assigneeId,
    DateTime? dueDate,
  }) async {
    try {
      await _client.from('tasks').insert({
        'room_id': roomId,
        'title': title,
        'created_by': _client.auth.currentUser!.id,
        'assignee_id': assigneeId,
        'due_date': dueDate?.toIso8601String().split('T').first,
      });
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> updateTaskStatus({
    required String roomId,
    required String taskId,
    required String status,
  }) async {
    try {
      await _client
          .from('tasks')
          .update({'status': status})
          .eq('id', taskId)
          .eq('room_id', roomId);
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final roomContentRepositoryProvider = Provider<RoomContentRepository>((ref) {
  return SupabaseRoomContentRepository(ref.watch(supabaseClientProvider));
});
