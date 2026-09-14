import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/rooms/ai_suggestions.dart';

/// Phase 3 model contracts: suggestion parsing, pending state, agent
/// registry rows (the human-in-the-loop pipeline's client shapes).
void main() {
  group('AiSuggestion', () {
    test('parses a pending suggestion with output payload', () {
      final s = AiSuggestion.fromMap({
        'id': 'sug-1',
        'room_id': 'room-1',
        'agent_type': 'contradiction_checker',
        'status': 'pending',
        'output': {
          'title': 'Dates conflict',
          'detail': 'Statement says March; contract says June',
          'items': ['statement.pdf', 'contract.pdf'],
          'provider': 'mock',
          'model': 'deterministic-v1',
        },
        'created_at': '2026-09-13T10:00:00Z',
        'reviewed_at': null,
      });

      expect(s.isPending, isTrue);
      expect(s.title, 'Dates conflict');
      expect(s.provider, 'mock');
      expect(s.agentType, 'contradiction_checker');
      expect(s.reviewedAt, isNull);
    });

    test('accepted suggestion reports not-pending + review time', () {
      final s = AiSuggestion.fromMap({
        'id': 'sug-2',
        'room_id': 'room-1',
        'agent_type': 'root_cause_suggester',
        'status': 'accepted',
        'output': {'title': 'Config drift'},
        'created_at': '2026-09-13T10:00:00Z',
        'reviewed_at': '2026-09-13T11:00:00Z',
      });

      expect(s.isPending, isFalse);
      expect(s.status, 'accepted');
      expect(s.reviewedAt, isNotNull);
    });

    test('non-map output falls back safely (never crashes the list)', () {
      final s = AiSuggestion.fromMap({
        'id': 'sug-3',
        'room_id': 'room-1',
        'agent_type': 'x',
        'status': 'dismissed',
        'output': null,
        'created_at': '2026-09-13T10:00:00Z',
      });

      expect(s.title, isNull);
      expect(s.detail, isNull);
      expect(s.isPending, isFalse);
    });
  });

  group('AgentDefinition', () {
    test('parses registry rows (0017 config data)', () {
      final a = AgentDefinition.fromMap({
        'id': 'financial_anomaly_detector',
        'display_name': 'Financial Anomaly Detector',
        'description': 'Flags unusual patterns in amounts.',
        'case_type': 'corporate',
      });

      expect(a.id, 'financial_anomaly_detector');
      expect(a.caseType, 'corporate');
      expect(a.description, contains('amounts'));
    });

    test('case-type-agnostic agents (null case_type) parse', () {
      final a = AgentDefinition.fromMap({
        'id': 'generic',
        'display_name': 'Generic',
        'description': '',
        'case_type': null,
      });
      expect(a.caseType, isNull);
    });
  });
}
