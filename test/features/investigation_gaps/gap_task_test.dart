import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';

void main() {
  group('InvestigationGap', () {
    test('parses an open gap', () {
      final g = InvestigationGap.fromMap({
        'id': 'gap-1',
        'room_id': 'room-1',
        'gap_type': 'missing_evidence',
        'description': 'No contract on file',
        'source_type': 'manual',
        'status': 'open',
        'created_by': 'user-1',
        'created_at': '2026-09-13T10:00:00Z',
      });

      expect(g.id, 'gap-1');
      expect(g.gapType, 'missing_evidence');
      expect(g.description, 'No contract on file');
      expect(g.status, GapStatus.open);
      expect(g.sourceType, ContradictionSourceType.manual);
      expect(g.linkedTaskId, isNull);
    });

    test('nullable fields default null', () {
      final g = InvestigationGap.fromMap({
        'id': 'gap-2',
        'room_id': 'room-1',
        'gap_type': 'unknown',
        'description': 'Something missing',
        'status': 'in_progress',
        'created_at': '2026-09-13T10:00:00Z',
      });

      expect(g.sourceType, isNull);
      expect(g.aiSuggestionId, isNull);
      expect(g.linkedTaskId, isNull);
      expect(g.createdBy, isNull);
      expect(g.resolvedAt, isNull);
    });
  });

  group('GapStatus enum', () {
    test('round-trips via .name', () {
      final status = GapStatus.inProgress;
      expect(GapStatus.values.firstWhere((e) => e.name == status.name), status);
    });
  });
}
