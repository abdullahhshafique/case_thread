import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';

void main() {
  group('CaseStatistics', () {
    test('parses a full statistics row', () {
      final s = CaseStatistics.fromMap({
        'room_id': 'room-1',
        'evidence_count': 3,
        'people_count': 5,
        'locations_count': 2,
        'events_count': 10,
        'contradictions_count': 1,
        'gaps_count': 2,
        'unverified_alibis_count': 1,
        'ai_findings_count': 4,
      });

      expect(s.roomId, 'room-1');
      expect(s.evidenceCount, 3);
      expect(s.peopleCount, 5);
      expect(s.locationsCount, 2);
      expect(s.eventsCount, 10);
      expect(s.contradictionsCount, 1);
      expect(s.gapsCount, 2);
      expect(s.unverifiedAlibisCount, 1);
      expect(s.aiFindingsCount, 4);
    });

    test('zero counts parse', () {
      final s = CaseStatistics.fromMap({
        'room_id': 'room-empty',
        'evidence_count': 0,
        'people_count': 0,
        'locations_count': 0,
        'events_count': 0,
        'contradictions_count': 0,
        'gaps_count': 0,
        'unverified_alibis_count': 0,
        'ai_findings_count': 0,
      });

      expect(s.evidenceCount, 0);
      expect(s.aiFindingsCount, 0);
    });
  });

  group('CaseClosedSummary', () {
    test('parses a summary', () {
      final s = CaseClosedSummary.fromMap({
        'id': 'sum-1',
        'room_id': 'room-1',
        'summary_json': {
          'room_id': 'room-1',
          'generated_at': '2026-09-13T12:00:00Z',
        },
        'generated_at': '2026-09-13T12:00:00Z',
        'generated_by': 'user-1',
      });

      expect(s.id, 'sum-1');
      expect(s.roomId, 'room-1');
      expect(s.generatedAt, isNotNull);
      expect(s.generatedBy, 'user-1');
      expect(s.summaryJson['room_id'], 'room-1');
    });

    test('nullable generatedBy defaults null', () {
      final s = CaseClosedSummary.fromMap({
        'id': 'sum-2',
        'room_id': 'room-2',
        'summary_json': {},
        'generated_at': '2026-09-13T12:00:00Z',
      });

      expect(s.generatedBy, isNull);
    });
  });

  group('InvestigationStatus enum', () {
    test('round-trips via .name', () {
      final status = InvestigationStatus.closed;
      expect(
        InvestigationStatus.values.firstWhere((e) => e.name == status.name),
        status,
      );
    });

    test('all statuses present', () {
      expect(InvestigationStatus.values, contains(InvestigationStatus.open));
      expect(
        InvestigationStatus.values,
        contains(InvestigationStatus.underInvestigation),
      );
      expect(InvestigationStatus.values, contains(InvestigationStatus.review));
      expect(InvestigationStatus.values, contains(InvestigationStatus.closed));
    });
  });
}
