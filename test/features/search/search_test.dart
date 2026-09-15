import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/search/search_repository.dart';

/// Phase 4 cross-case-search contracts (0022): hit parsing for every
/// object type + the short-query guard the UI relies on.
void main() {
  group('SearchHit', () {
    test('parses a discussion hit', () {
      final hit = SearchHit.fromMap({
        'room_id': 'r-1',
        'room_name': 'Alpha Fraud Matter',
        'case_type': 'legal',
        'object_type': 'discussion',
        'object_id': 'm-1',
        'snippet': 'The witness memo mentions the ledger.',
        'created_at': '2026-09-15T10:00:00Z',
      });

      expect(hit.roomId, 'r-1');
      expect(hit.roomName, 'Alpha Fraud Matter');
      expect(hit.caseType, 'legal');
      expect(hit.objectType, 'discussion');
      expect(hit.snippet, 'The witness memo mentions the ledger.');
      expect(hit.createdAt.toUtc(), DateTime.parse('2026-09-15T10:00:00Z'));
    });

    test('parses an evidence hit with a filename snippet', () {
      final hit = SearchHit.fromMap({
        'room_id': 'r-1',
        'room_name': 'Alpha Fraud Matter',
        'case_type': 'legal',
        'object_type': 'evidence',
        'object_id': 'e-1',
        'snippet': 'ledger-scan.pdf',
        'created_at': '2026-09-15T09:00:00Z',
      });

      expect(hit.objectType, 'evidence');
      expect(hit.snippet, 'ledger-scan.pdf');
    });

    test('room hits tolerate an empty snippet (name is the snippet)', () {
      final hit = SearchHit.fromMap({
        'room_id': 'r-2',
        'room_name': 'Beta Contract Dispute',
        'case_type': 'legal',
        'object_type': 'room',
        'object_id': '',
        'snippet': '',
        'created_at': '2026-09-15T08:00:00Z',
      });

      expect(hit.objectType, 'room');
      expect(hit.snippet, '');
    });
  });

  group('SearchQueryState', () {
    test('starts empty with no hits', () {
      const state = SearchQueryState();
      expect(state.query, '');
      expect(state.hits, isEmpty);
    });
  });
}
