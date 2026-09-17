import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';

void main() {
  group('CaseBreakdown', () {
    test('parses evidence_by_type and events_per_day', () {
      final b = CaseBreakdown.fromMap({
        'evidence_by_type': {'pdf': 3, 'image': 1},
        'events_per_day': {'2026-09-15': 4, '2026-09-16': 2},
      });

      expect(b.evidenceByType['pdf'], 3);
      expect(b.evidenceByType['image'], 1);
      expect(b.eventsPerDay['2026-09-15'], 4);
      expect(b.eventsPerDay.length, 2);
    });

    test('handles empty maps', () {
      final b = CaseBreakdown.fromMap({
        'evidence_by_type': {},
        'events_per_day': {},
      });

      expect(b.evidenceByType, isEmpty);
      expect(b.eventsPerDay, isEmpty);
    });
  });
}
