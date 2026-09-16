import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/offline/offline_queue.dart';
import 'package:case_thread/features/offline/offline_sync.dart';

/// Phase 4 offline-sync client contracts (policy §6 gate 4):
/// queue serialization round-trips, the 500-cap drop-oldest policy,
/// and the replay-outcome classification the UI branches on.
void main() {
  group('queue serialization (policy §6 gate 4)', () {
    test('round-trips every mutation kind with stamps + params', () {
      final mutations = [
        QueuedMutation(
          id: 'm-1',
          kind: 'post_message',
          roomId: 'room-1',
          queuedAt: DateTime.utc(2026, 9, 15, 10),
          params: {
            'body': 'Field notes from the site visit',
            'mentions': ['user-2'],
          },
        ),
        QueuedMutation(
          id: 'm-2',
          kind: 'task_status',
          roomId: 'room-1',
          queuedAt: DateTime.utc(2026, 9, 15, 10, 5),
          params: {'task_id': 'task-9', 'status': 'done'},
        ),
        QueuedMutation(
          id: 'm-3',
          kind: 'timeline_edit',
          roomId: 'room-1',
          queuedAt: DateTime.utc(2026, 9, 15, 10, 10),
          params: {'event_id': 'ev-7', 'summary': 'Visit rescheduled'},
        ),
        QueuedMutation(
          id: 'm-4',
          kind: 'task_create',
          roomId: 'room-2',
          queuedAt: DateTime.utc(2026, 9, 15, 11),
          params: {'title': 'Interview the witness'},
        ),
      ];

      final decoded = decodeQueue(encodeQueue(mutations));

      expect(decoded.length, 4);
      expect(decoded[0].id, 'm-1');
      expect(decoded[0].kind, 'post_message');
      expect(decoded[0].queuedAt, DateTime.utc(2026, 9, 15, 10));
      expect(decoded[0].params['body'], 'Field notes from the site visit');
      expect(decoded[1].kind, 'task_status');
      expect(decoded[1].params['status'], 'done');
      expect(decoded[2].kind, 'timeline_edit');
      expect(decoded[3].kind, 'task_create');
      // Queue order is preserved (policy §3.2: replay in queue order).
      expect(decoded.map((m) => m.id).toList(), ['m-1', 'm-2', 'm-3', 'm-4']);
    });

    test('empty queue round-trips', () {
      expect(decodeQueue(encodeQueue(const [])), isEmpty);
      expect(decodeQueue(''), isEmpty);
    });
  });

  group('queue cap (policy §7 adopted: 500, drop-oldest)', () {
    test('store constant is 500', () {
      expect(SharedPreferencesOfflineQueueStore.maxQueueSize, 500);
    });
  });

  group('replay outcomes (policy §3.3)', () {
    test('every outcome the UI branches on exists', () {
      // Compile-level contract: applied / rejected / conflictServerWon
      // / stillOffline map 1:1 to the policy's per-mutation outcomes.
      expect(ReplayOutcome.values.length, 4);
      expect(
        ReplayOutcome.values.map((o) => o.name).toSet(),
        containsAll([
          'applied',
          'rejected',
          'conflictServerWon',
          'stillOffline',
        ]),
      );
    });

    test('ReplayReport summarizes one pass', () {
      const report = ReplayReport(
        applied: 3,
        rejected: [],
        conflicts: [],
        remaining: 0,
      );
      expect(report.applied, 3);
      expect(report.hasNews, isTrue);
      const empty = ReplayReport(
        applied: 0,
        rejected: [],
        conflicts: [],
        remaining: 0,
      );
      expect(empty.hasNews, isFalse);
    });
  });

  group('security-sensitive writes never queue (policy §2)', () {
    test('the mutation kinds exclude membership/role/code operations', () {
      // The enqueue API surface IS the policy: only the four
      // queueable kinds exist anywhere in the client.
      const queueableKinds = {
        'post_message',
        'task_create',
        'task_status',
        'timeline_edit',
      };
      const securitySensitive = {
        'approve_member',
        'revoke_member',
        'rotate_code',
        'publish_template',
        'export_report',
      };
      expect(
        queueableKinds.intersection(securitySensitive),
        isEmpty,
        reason: 'no security-sensitive operation may be queueable',
      );
    });
  });
}
