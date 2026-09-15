import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline queue v1 (docs/offline-sync-conflict-policy.md, approved
/// gate). Storage half of the client design:
///
///   * A single JSON array under one SharedPreferences key — atomic
///     swap on every mutation, no new dependency (Rules.md §4).
///   * Cap 500 mutations, drop-oldest (policy §7 proposal, adopted).
///   * Security-sensitive writes (membership, roles, codes) never
///     enter this queue — the enqueue API has no methods for them.

/// One queued mutation. [kind] selects the replay path; [queuedAt] is
/// the LWW stamp the server compares against (0023).
@immutable
class QueuedMutation {
  const QueuedMutation({
    required this.id,
    required this.kind,
    required this.roomId,
    required this.queuedAt,
    this.params = const {},
  });

  /// Stable unique id (also the de-dupe key at replay).
  final String id;

  /// 'post_message' | 'task_create' | 'task_status' | 'timeline_edit'.
  final String kind;
  final String roomId;

  /// When the offline device wrote this (LWW stamp).
  final DateTime queuedAt;
  final Map<String, dynamic> params;

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind,
    'room_id': roomId,
    'queued_at': queuedAt.toIso8601String(),
    'params': params,
  };

  factory QueuedMutation.fromMap(Map<String, dynamic> map) {
    return QueuedMutation(
      id: map['id'] as String,
      kind: map['kind'] as String,
      roomId: map['room_id'] as String,
      queuedAt: DateTime.parse(map['queued_at'] as String),
      params: Map<String, dynamic>.from(map['params'] as Map),
    );
  }
}

/// Replay outcome per mutation (policy §3.3).
enum ReplayOutcome {
  /// Applied server-side; drop from the queue.
  applied,

  /// RLS / permission deny (e.g. revoked while offline). Drop from the
  /// queue, record in the rejected list with the typed message.
  rejected,

  /// LWW loss — server state won; the affected row is flagged
  /// server-side (visible conflict chip). Drop from the queue.
  conflictServerWon,

  /// Network still down mid-replay — keep for the next attempt.
  stillOffline,
}

/// A mutation the server rejected at replay (surfaced in the UI with
/// the role-specific message per policy §3.3 / PRD §6.7).
@immutable
class RejectedMutation {
  const RejectedMutation({required this.mutation, required this.reason});

  final QueuedMutation mutation;
  final String reason;
}

/// Abstract queue storage so tests run without a plugin.
abstract class OfflineQueueStore {
  Future<List<QueuedMutation>> load();
  Future<void> save(List<QueuedMutation> mutations);
}

class SharedPreferencesOfflineQueueStore implements OfflineQueueStore {
  static const _key = 'casethread.offline.queue.v1';

  /// Policy §7 adopted proposal: cap the queue, drop oldest first.
  static const maxQueueSize = 500;

  @override
  Future<List<QueuedMutation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((m) => QueuedMutation.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      return list;
    } on FormatException {
      return []; // corrupt queue = start clean rather than crash-loop
    }
  }

  @override
  Future<void> save(List<QueuedMutation> mutations) async {
    final prefs = await SharedPreferences.getInstance();
    final bounded = mutations.length > maxQueueSize
        ? mutations.sublist(mutations.length - maxQueueSize)
        : mutations;
    await prefs.setString(
      _key,
      jsonEncode([for (final m in bounded) m.toMap()]),
    );
  }
}

/// Pure serialization round-trip helper (unit-tested without a plugin:
/// the queue serialization contract is policy §6 gate 4).
String encodeQueue(List<QueuedMutation> mutations) {
  return jsonEncode([for (final m in mutations) m.toMap()]);
}

List<QueuedMutation> decodeQueue(String raw) {
  if (raw.isEmpty) return [];
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((m) => QueuedMutation.fromMap(Map<String, dynamic>.from(m)))
      .toList();
}
