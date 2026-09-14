import 'package:flutter_test/flutter_test.dart';

import 'package:case_thread/features/rooms/ai_suggestions.dart';
import 'package:case_thread/features/rooms/workflows.dart';

/// Phase 3 workflow-builder contracts (0018): chain models, run
/// parsing, agent-chain labels, and the human-edited output shape
/// the review dialog submits to review_suggestion (0017 'edited').
void main() {
  const agents = [
    AgentDefinition(
      id: 'contradiction_checker',
      displayName: 'Contradiction Checker',
      description: '',
      caseType: 'legal',
    ),
    AgentDefinition(
      id: 'root_cause_suggester',
      displayName: 'Root-Cause Suggester',
      description: '',
      caseType: 'technical',
    ),
    AgentDefinition(
      id: 'generic_agent',
      displayName: 'Generic',
      description: '',
      caseType: null,
    ),
  ];

  group('AiWorkflow', () {
    test('parses a stored chain row (steps ordered)', () {
      final wf = AiWorkflow.fromMap({
        'id': 'wf-1',
        'room_id': 'room-1',
        'name': 'Full sweep',
        'steps': ['contradiction_checker', 'generic_agent'],
        'created_by': 'user-1',
      });

      expect(wf.id, 'wf-1');
      expect(wf.roomId, 'room-1');
      expect(wf.steps, ['contradiction_checker', 'generic_agent']);
      expect(wf.createdBy, 'user-1');
    });

    test('chainLabel joins agent display names with arrows', () {
      final wf = AiWorkflow.fromMap({
        'id': 'wf-1',
        'room_id': 'room-1',
        'name': 'x',
        'steps': ['contradiction_checker', 'generic_agent'],
      });

      expect(wf.chainLabel(agents), 'Contradiction Checker → Generic');
    });

    test('chainLabel falls back to raw id for unknown agents', () {
      final wf = AiWorkflow.fromMap({
        'id': 'wf-1',
        'room_id': 'room-1',
        'name': 'x',
        'steps': ['retired_agent'],
      });

      expect(wf.chainLabel(agents), 'retired_agent');
    });

    test('toInsertMap carries room, name, and steps for insert', () {
      final wf = AiWorkflow.fromMap({
        'id': 'wf-1',
        'room_id': 'room-1',
        'name': 'Sweep',
        'steps': ['generic_agent'],
      });

      final map = wf.toInsertMap();
      expect(map['room_id'], 'room-1');
      expect(map['name'], 'Sweep');
      expect(map['steps'], ['generic_agent']);
    });

    test('non-list steps parse to empty (defensive)', () {
      final wf = AiWorkflow.fromMap({
        'id': 'wf-1',
        'room_id': 'room-1',
        'name': 'x',
        'steps': null,
      });
      expect(wf.steps, isEmpty);
    });
  });

  group('AiWorkflowRun', () {
    test('parses a running run', () {
      final run = AiWorkflowRun.fromMap({
        'id': 'run-1',
        'workflow_id': 'wf-1',
        'room_id': 'room-1',
        'status': 'running',
        'steps_total': 3,
        'steps_done': 1,
        'error': null,
        'created_at': '2026-09-14T10:00:00Z',
      });

      expect(run.isRunning, isTrue);
      expect(run.stepsTotal, 3);
      expect(run.stepsDone, 1);
      expect(run.error, isNull);
    });

    test('parses a failed run with error text', () {
      final run = AiWorkflowRun.fromMap({
        'id': 'run-2',
        'workflow_id': 'wf-1',
        'room_id': 'room-1',
        'status': 'failed',
        'steps_total': 2,
        'steps_done': 1,
        'error': 'provider_error: grok 429',
        'created_at': '2026-09-14T10:00:00Z',
      });

      expect(run.isRunning, isFalse);
      expect(run.status, 'failed');
      expect(run.error, contains('429'));
    });

    test('null steps_done parses to 0', () {
      final run = AiWorkflowRun.fromMap({
        'id': 'run-3',
        'workflow_id': 'wf-1',
        'room_id': 'room-1',
        'status': 'completed',
        'steps_total': 1,
        'created_at': '2026-09-14T10:00:00Z',
      });
      expect(run.stepsDone, 0);
    });
  });

  group('Edited suggestion output (review dialog contract)', () {
    test('human edit preserves provenance + marks human_edited', () {
      // Mirrors _EditSuggestionDialog._submit: the HUMAN text replaces
      // title/detail; provider/agent provenance rides along so the
      // review trail shows AI-proposed vs human-accepted.
      final base = AiSuggestion.fromMap({
        'id': 'sug-1',
        'room_id': 'room-1',
        'agent_type': 'contradiction_checker',
        'status': 'pending',
        'output': {
          'title': 'Dates conflict',
          'detail': 'Statement says March; contract says June',
          'provider': 'grok',
        },
        'created_at': '2026-09-14T10:00:00Z',
      });

      // What the dialog submits (title/detail fields, human_edited).
      final edited = {
        'title': 'Reconciled date conflict',
        'detail': 'Statement says March; signed contract says June.',
        'agent_type': base.agentType,
        'provider': base.provider,
        'human_edited': true,
      };

      expect(edited['title'], 'Reconciled date conflict');
      expect(edited['agent_type'], 'contradiction_checker');
      expect(edited['provider'], 'grok');
      expect(edited['human_edited'], isTrue);
      expect(edited.containsKey('model'), isFalse); // not surfaced in UI
    });
  });
}
