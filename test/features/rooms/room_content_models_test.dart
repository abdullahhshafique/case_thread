import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/rooms/domain/room_content_models.dart';

/// Sprint 5 model + parser contracts.
void main() {
  group('parseMentions (PRD §6.6 @mentions)', () {
    test('matches a full display name', () {
      final mentioned = parseMentions(
        'Can @Priya Sharma take the lead on the filing?',
        ['Priya Sharma', 'Elena'],
      );
      expect(mentioned, ['Priya Sharma']);
    });

    test('matches multiple distinct members', () {
      final mentioned = parseMentions(
        '@Elena will review; @Priya Sharma will approve.',
        ['Priya Sharma', 'Elena'],
      );
      expect(mentioned.toSet(), {'Elena', 'Priya Sharma'});
    });

    test('is case-insensitive', () {
      final mentioned = parseMentions('ping @elena when done', ['Elena']);
      expect(mentioned, ['Elena']);
    });

    test('no @-token means no mentions', () {
      expect(parseMentions('Great work team', ['Elena']), isEmpty);
    });

    test('name without @ prefix is not a mention', () {
      expect(parseMentions('Elena will review later', ['Elena']), isEmpty);
    });

    test('empty body or member list yields nothing', () {
      expect(parseMentions('', ['Elena']), isEmpty);
      expect(parseMentions('hello @Elena', []), isEmpty);
    });
  });

  group('TimelineEventModel', () {
    test('parses a system event with payload + profile embed', () {
      final event = TimelineEventModel.fromMap({
        'id': 'te-1',
        'room_id': 'room-1',
        'event_type': 'system',
        'actor_id': 'u-1',
        'occurred_at': '2026-09-12T10:00:00Z',
        'payload': {
          'summary': 'Evidence uploaded',
          'action_type': 'evidence_uploaded',
          'details': {'filename': 'contract.pdf'},
        },
        'profiles': {'display_name': 'Priya'},
      });

      expect(event.eventType, 'system');
      expect(event.summary, 'Evidence uploaded');
      expect(event.actionType, 'evidence_uploaded');
      expect(event.actorName, 'Priya');
      expect(event.displaySummary, 'Evidence uploaded');
    });

    test('manual events fall back to payload summary', () {
      final event = TimelineEventModel.fromMap({
        'id': 'te-2',
        'room_id': 'room-1',
        'event_type': 'manual',
        'actor_id': 'u-2',
        'occurred_at': '2026-09-12T10:00:00Z',
        'payload': {'summary': 'Hearing scheduled'},
      });

      expect(event.displaySummary, 'Hearing scheduled');
    });

    test('handles string-encoded payload defensively', () {
      final event = TimelineEventModel.fromMap({
        'id': 'te-3',
        'room_id': 'room-1',
        'event_type': 'manual',
        'actor_id': null,
        'occurred_at': '2026-09-12T10:00:00Z',
        'payload': '{"summary":"Parsed from string"}',
      });

      expect(event.displaySummary, 'Parsed from string');
    });
  });

  group('DiscussionMessage', () {
    test('parses mentions array and author embed', () {
      final message = DiscussionMessage.fromMap({
        'id': 'dm-1',
        'room_id': 'room-1',
        'author_id': 'u-1',
        'body': 'Please review @Elena',
        'mentions': ['u-2'],
        'created_at': '2026-09-12T10:00:00Z',
        'profiles': {'display_name': 'Priya'},
      });

      expect(message.mentions, ['u-2']);
      expect(message.authorName, 'Priya');
      expect(message.body, contains('@Elena'));
    });

    test('missing mentions fall back to empty', () {
      final message = DiscussionMessage.fromMap({
        'id': 'dm-2',
        'room_id': 'room-1',
        'author_id': 'u-1',
        'body': 'Plain message',
        'created_at': '2026-09-12T10:00:00Z',
      });
      expect(message.mentions, isEmpty);
      expect(message.parentMessageId, isNull);
    });
  });

  group('TaskModel', () {
    test('parses assignee embed and due date', () {
      final task = TaskModel.fromMap({
        'id': 'tk-1',
        'room_id': 'room-1',
        'title': 'Interview the witness',
        'assignee_id': 'u-2',
        'assignee': {'display_name': 'Elena'},
        'due_date': '2026-09-20',
        'status': 'in_progress',
        'created_by': 'u-1',
        'created_at': '2026-09-12T10:00:00Z',
      });

      expect(task.assigneeName, 'Elena');
      expect(task.isDone, isFalse);
      expect(task.dueDate, isNotNull);
    });

    test('done status + unassigned tasks parse safely', () {
      final task = TaskModel.fromMap({
        'id': 'tk-2',
        'room_id': 'room-1',
        'title': 'Done thing',
        'status': 'done',
        'created_by': 'u-1',
        'created_at': '2026-09-12T10:00:00Z',
      });

      expect(task.isDone, isTrue);
      expect(task.assigneeName, isNull);
    });
  });
}
