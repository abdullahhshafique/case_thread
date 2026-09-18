import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/core/api/models.dart';

void main() {
  group('Contradiction', () {
    test('parses a manual contradiction', () {
      final c = Contradiction.fromMap({
        'id': 'con-1',
        'room_id': 'room-1',
        'source_type': 'manual',
        'conflicting_detail': 'Statement says June; contract says March',
        'flagged_reason': 'Reviewed both docs',
        'status': 'open',
        'created_at': '2026-09-13T10:00:00Z',
        'flagged_by': 'user-1',
      });

      expect(c.id, 'con-1');
      expect(c.sourceType, ContradictionSourceType.manual);
      expect(c.conflictingDetail, contains('June'));
      expect(c.status, ContradictionStatus.open);
      expect(c.flaggedBy, 'user-1');
      expect(c.aiSuggestionId, isNull);
      expect(c.resolutionNote, isNull);
      expect(c.resolvedAt, isNull);
    });

    test('parses an AI-suggestion contradiction', () {
      final c = Contradiction.fromMap({
        'id': 'con-2',
        'room_id': 'room-1',
        'source_type': 'ai_suggestion',
        'conflicting_detail': 'AI flagged date conflict',
        'flagged_reason': 'auto',
        'status': 'resolved',
        'created_at': '2026-09-13T10:00:00Z',
        'ai_suggestion_id': 'sug-1',
        'resolution_note': 'Statement corrected',
        'resolved_at': '2026-09-13T12:00:00Z',
      });

      expect(c.sourceType, ContradictionSourceType.aiSuggestion);
      expect(c.aiSuggestionId, 'sug-1');
      expect(c.status, ContradictionStatus.resolved);
      expect(c.resolutionNote, 'Statement corrected');
    });
  });

  group('ContradictionStatus enum', () {
    test('round-trips via .name', () {
      final status = ContradictionStatus.resolved;
      expect(
        ContradictionStatus.values.firstWhere((e) => e.name == status.name),
        status,
      );
    });
  });

  group('ContradictionSourceType enum', () {
    test('round-trips via .name', () {
      expect(ContradictionSourceType.manual.name, 'manual');
      expect(ContradictionSourceType.aiSuggestion.name, 'aiSuggestion');
      // SQL stores snake_case; models.dart maps via switch, not .name.
      expect(
        ContradictionSourceType.values.firstWhere(
          (e) => e.name == 'aiSuggestion',
        ),
        ContradictionSourceType.aiSuggestion,
      );
    });
  });
}
