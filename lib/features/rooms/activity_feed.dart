import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../auth/auth_providers.dart';

/// One unseen activity item (0014 v_activity_feed).
class ActivityItem {
  const ActivityItem({
    required this.roomId,
    required this.actionType,
    required this.objectType,
    required this.createdAt,
  });

  final String roomId;
  final String actionType;
  final String objectType;
  final DateTime createdAt;

  factory ActivityItem.fromMap(Map<String, dynamic> map) {
    return ActivityItem(
      roomId: map['room_id'] as String,
      actionType: map['action_type'] as String,
      objectType: map['object_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  String get label => switch (actionType) {
    'room_created' => 'New room activity',
    'join_requested' => 'Someone asked to join',
    'join_approved' => 'A new member joined',
    'member_revoked' => 'A member was removed',
    'evidence_uploaded' => 'New evidence uploaded',
    'code_rotated' => 'Access code rotated',
    'task_created' => 'A new task was created',
    'task_updated' => 'A task changed',
    'timeline_event_edited' => 'A timeline event was edited',
    _ => 'Case activity',
  };
}

/// Activity feed contract (Phase 2): the feed = audit rows in the
/// caller's rooms newer than their per-room watermark (0014).
abstract class ActivityFeedRepository {
  /// Unseen items, newest first. Redaction-aware (privileged payload
  /// fields never included for roles without view_privileged).
  Future<List<ActivityItem>> getFeed();

  /// Marks a room seen (clears its feed items).
  Future<void> markRoomSeen(String roomId);
}

class SupabaseActivityFeedRepository implements ActivityFeedRepository {
  SupabaseActivityFeedRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<ActivityItem>> getFeed() async {
    final rows = await _client
        .from('v_activity_feed')
        .select('room_id, action_type, object_type, created_at')
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List)
        .map((row) => ActivityItem.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<void> markRoomSeen(String roomId) async {
    await _client.from('room_last_seen').upsert({
      'user_id': _client.auth.currentUser!.id,
      'room_id': roomId,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id, room_id');
  }
}

final activityFeedRepositoryProvider = Provider<ActivityFeedRepository>((ref) {
  return SupabaseActivityFeedRepository(ref.watch(supabaseClientProvider));
});
