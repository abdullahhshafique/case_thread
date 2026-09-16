import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/history/version_history_repository.dart';

/// Phase 4 version-history contracts (0024): entry parsing for both
/// object kinds + action vocabulary the sheet renders.
void main() {
  group('VersionEntry', () {
    test('parses a task creation entry', () {
      final entry = VersionEntry.fromMap({
        'version_no': 1,
        'actor_name': 'Aisha Khan',
        'action': 'created',
        'detail': 'Draft the motion → open',
        'changed_at': '2026-09-15T09:00:00Z',
      });

      expect(entry.versionNo, 1);
      expect(entry.actorName, 'Aisha Khan');
      expect(entry.action, 'created');
      expect(entry.detail, 'Draft the motion → open');
      expect(entry.changedAt.toUtc(), DateTime.parse('2026-09-15T09:00:00Z'));
    });

    test('parses a timeline edit entry (edits start at v2)', () {
      final entry = VersionEntry.fromMap({
        'version_no': 2,
        'actor_name': null,
        'action': 'edited',
        'detail': '"Kickoff call held" → "Kickoff call held; follow-up"',
        'changed_at': '2026-09-15T10:30:00Z',
      });

      expect(entry.versionNo, 2);
      expect(entry.actorName, isNull);
      expect(entry.action, 'edited');
    });

    test('tolerates a missing detail', () {
      final entry = VersionEntry.fromMap({
        'version_no': 3,
        'action': 'status_changed',
        'detail': null,
        'changed_at': '2026-09-15T11:00:00Z',
      });

      expect(entry.detail, '');
    });
  });
}
