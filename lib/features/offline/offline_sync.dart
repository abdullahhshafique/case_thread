import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import 'offline_queue.dart';

/// Offline sync controller (policy §3): enqueue on network failure,
/// ordered replay on reconnect through the SAME endpoints as live
/// writes, per-mutation typed outcomes. The UI layer wraps writes in
/// [OfflineSync.run] — online calls go straight through; offline ones
/// queue and the pane shows the queued state.
class OfflineSync {
  OfflineSync({required this._store, required this._client});

  final OfflineQueueStore _store;
  final supabase.SupabaseClient _client;

  /// Wraps a write: try live; on network failure queue it. Returns
  /// true when the write landed (live) or queued (offline); non-network
  /// failures rethrow for the UI to show (typed).
  Future<bool> run(
    String roomId,
    String kind,
    Map<String, dynamic> params,
    Future<void> Function() liveWrite,
  ) async {
    try {
      await liveWrite();
      return true; // landed live
    } on AppException catch (error) {
      if (error is! NetworkException) {
        rethrow; // permission/validation errors are server-verified
      }
      await enqueue(
        QueuedMutation(
          id: _mutationId(),
          kind: kind,
          roomId: roomId,
          queuedAt: DateTime.now(),
          params: params,
        ),
      );
      return true; // queued
    }
  }

  Future<void> enqueue(QueuedMutation mutation) async {
    final queue = await _store.load();
    queue.add(mutation);
    await _store.save(queue);
  }

  /// Replays the queue in order (policy §3.2). Returns outcomes so the
  /// caller can refresh streams + surface rejections; mutations that
  /// hit the network stay queued for the next attempt.
  Future<ReplayReport> replay() async {
    final queue = await _store.load();
    final remaining = <QueuedMutation>[];
    final rejected = <RejectedMutation>[];
    final conflicts = <QueuedMutation>[];
    var applied = 0;

    for (final mutation in queue) {
      final outcome = await _replayOne(mutation);
      switch (outcome) {
        case ReplayOutcome.applied:
          applied++;
        case ReplayOutcome.rejected:
          rejected.add(
            RejectedMutation(mutation: mutation, reason: _describe(mutation)),
          );
        case ReplayOutcome.conflictServerWon:
          conflicts.add(mutation);
        case ReplayOutcome.stillOffline:
          remaining.add(mutation);
      }
    }

    await _store.save(remaining);
    return ReplayReport(
      applied: applied,
      rejected: rejected,
      conflicts: conflicts,
      remaining: remaining.length,
    );
  }

  Future<ReplayOutcome> _replayOne(QueuedMutation mutation) async {
    try {
      switch (mutation.kind) {
        case 'post_message':
          await _client.from('discussion_messages').insert({
            'room_id': mutation.roomId,
            'author_id': _client.auth.currentUser!.id,
            'body': mutation.params['body'] as String,
            'parent_message_id': mutation.params['parent_message_id'],
            'mentions': mutation.params['mentions'] ?? const [],
          });
        case 'task_create':
          await _client.from('tasks').insert({
            'room_id': mutation.roomId,
            'created_by': _client.auth.currentUser!.id,
            'title': mutation.params['title'] as String,
            'assignee_id': mutation.params['assignee_id'],
          });
        case 'task_status':
          final result = await _client.rpc(
            'update_task_with_stamp',
            params: {
              'target_task': mutation.params['task_id'],
              'new_status': mutation.params['status'],
              'client_value_at': mutation.queuedAt.toIso8601String(),
            },
          ) as String;
          if (result == 'conflict_server_won') {
            return ReplayOutcome.conflictServerWon;
          }
        case 'timeline_edit':
          final result = await _client.rpc(
            'edit_timeline_event_with_stamp',
            params: {
              'target_event': mutation.params['event_id'],
              'new_summary': mutation.params['summary'],
              'client_value_at': mutation.queuedAt.toIso8601String(),
            },
          ) as String;
          if (result == 'conflict_server_won') {
            return ReplayOutcome.conflictServerWon;
          }
        default:
          return ReplayOutcome.rejected; // unknown kind: drop + surface
      }
      return ReplayOutcome.applied;
    } on AppException catch (error) {
      return switch (error) {
        NetworkException() => ReplayOutcome.stillOffline,
        // Server-side permission/RLS deny — typed message, drop it.
        PermissionDeniedException() ||
        AccessRevokedException() ||
        RoleNotAllowedException() => ReplayOutcome.rejected,
        _ => ReplayOutcome.rejected, // typed but unexpected: surface it
      };
    } catch (error) {
      final appError = toAppException(error);
      return appError is NetworkException
          ? ReplayOutcome.stillOffline
          : ReplayOutcome.rejected;
    }
  }

  String _describe(QueuedMutation mutation) {
    return switch (mutation.kind) {
      'post_message' =>
        'A message you wrote offline couldn\'t be sent — your access '
            'may have changed.',
      'task_create' =>
        'A task you created offline couldn\'t be saved — your access '
            'may have changed.',
      'task_status' =>
        'A task update you made offline was rejected — your role may '
            'have changed.',
      'timeline_edit' =>
        'An event edit you made offline was rejected — your role may '
            'have changed.',
      _ => 'An offline change couldn\'t be synced.',
    };
  }

  String _mutationId() {
    final now = DateTime.now();
    return '${now.microsecondsSinceEpoch}-${identityHashCode(this)}';
  }

  /// Clears a conflict flag server-side (clear_conflict RPC, 0023).
  /// Permission-gated + audited there; typed errors bubble to the UI.
  Future<void> clearConflict(String objectKind, String objectId) {
    return _client.rpc(
      'clear_conflict',
      params: {'object_kind': objectKind, 'target_id': objectId},
    );
  }
}

/// Summary of one replay pass (policy §3.3 outcomes).
@immutable
class ReplayReport {
  const ReplayReport({
    required this.applied,
    required this.rejected,
    required this.conflicts,
    required this.remaining,
  });

  final int applied;
  final List<RejectedMutation> rejected;
  final List<QueuedMutation> conflicts;
  final int remaining;

  bool get hasNews =>
      applied > 0 || rejected.isNotEmpty || conflicts.isNotEmpty;
}
