import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';
import 'ai_suggestions.dart' show AgentDefinition;

/// A saved agent chain (0018): the workflow builder's data. `steps`
/// are ordered agent ids — each still produces its own PENDING
/// suggestion when run (Rules.md §11 human-in-the-loop per step).
class AiWorkflow {
  const AiWorkflow({
    required this.id,
    required this.roomId,
    required this.name,
    required this.steps,
    this.createdBy,
  });

  final String id;
  final String roomId;
  final String name;

  /// Ordered agent ids (1–5, server-enforced).
  final List<String> steps;
  final String? createdBy;

  /// Chain label for cards, e.g. "A → B → C" (agent display names).
  String chainLabel(List<AgentDefinition> agents) {
    final byId = {for (final a in agents) a.id: a.displayName};
    return steps.map((s) => byId[s] ?? s).join(' → ');
  }

  factory AiWorkflow.fromMap(Map<String, dynamic> map) {
    return AiWorkflow(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      name: map['name'] as String,
      steps: map['steps'] is List
          ? List<String>.from(map['steps'] as List)
          : const [],
      createdBy: map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() => {
    'room_id': roomId,
    'name': name,
    'steps': steps,
  };
}

/// One chained execution (service-role written; clients watch it).
class AiWorkflowRun {
  const AiWorkflowRun({
    required this.id,
    required this.workflowId,
    required this.roomId,
    required this.status,
    required this.stepsTotal,
    required this.stepsDone,
    required this.createdAt,
    this.error,
  });

  final String id;
  final String workflowId;
  final String roomId;

  /// running | completed | failed.
  final String status;
  final int stepsTotal;
  final int stepsDone;
  final String? error;
  final DateTime createdAt;

  bool get isRunning => status == 'running';

  factory AiWorkflowRun.fromMap(Map<String, dynamic> map) {
    return AiWorkflowRun(
      id: map['id'] as String,
      workflowId: map['workflow_id'] as String,
      roomId: map['room_id'] as String,
      status: map['status'] as String,
      stepsTotal: map['steps_total'] as int,
      stepsDone: (map['steps_done'] as int?) ?? 0,
      error: map['error'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Workflow-builder contract: human-written configs (edit_case) +
/// service-role runs via the ai-agent Edge Function (chain mode).
abstract class AiWorkflowRepository {
  /// Room's saved workflows, newest first.
  Future<List<AiWorkflow>> listWorkflows(String roomId);

  /// Realtime run stream for a room (0018 added runs to the
  /// supabase_realtime publication — progress pushes live).
  Stream<List<AiWorkflowRun>> watchRuns(String roomId);

  Future<void> saveWorkflow({
    required String roomId,
    required String name,
    required List<String> steps,
  });

  Future<void> deleteWorkflow(String workflowId);

  /// Runs a saved chain; returns the run id + created-suggestion count,
  /// or throws on provider/permission failure.
  Future<({String runId, int suggestionsCreated})> runWorkflow(
    String workflowId,
  );
}

class SupabaseAiWorkflowRepository implements AiWorkflowRepository {
  SupabaseAiWorkflowRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<AiWorkflow>> listWorkflows(String roomId) async {
    final rows = await _client
        .from('ai_workflows')
        .select('id, room_id, name, steps, created_by')
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AiWorkflow.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Stream<List<AiWorkflowRun>> watchRuns(String roomId) {
    return _client
        .from('ai_workflow_runs')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map(
          (rows) => rows
              .map(
                (row) => AiWorkflowRun.fromMap(Map<String, dynamic>.from(row)),
              )
              .toList()
              .reversed
              .toList(), // newest first
        );
  }

  @override
  Future<void> saveWorkflow({
    required String roomId,
    required String name,
    required List<String> steps,
  }) async {
    try {
      await _client.from('ai_workflows').insert({
        'room_id': roomId,
        'name': name,
        'steps': steps,
      });
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> deleteWorkflow(String workflowId) async {
    try {
      await _client.from('ai_workflows').delete().eq('id', workflowId);
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<({String runId, int suggestionsCreated})> runWorkflow(
    String workflowId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'ai-agent',
        body: {'workflow_id': workflowId},
      );
      final data = Map<String, dynamic>.from(
        (response.data as Map).cast<String, dynamic>(),
      );
      if (data['status'] == 'workflow_completed' ||
          data['status'] == 'workflow_failed') {
        return (
          runId: data['run_id'] as String,
          suggestionsCreated:
              (data['suggestions_created'] as num?)?.toInt() ?? 0,
        );
      }
      if (data['code'] == 'forbidden') {
        throw Exception(data['message']);
      }
      throw Exception('The workflow run failed. Try again.');
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final aiWorkflowRepositoryProvider = Provider<AiWorkflowRepository>((ref) {
  return SupabaseAiWorkflowRepository(ref.watch(supabaseClientProvider));
});

/// Saved workflows per room.
final workflowsProvider = FutureProvider.family<List<AiWorkflow>, String>((
  ref,
  roomId,
) {
  return ref.watch(aiWorkflowRepositoryProvider).listWorkflows(roomId);
});

/// Realtime run stream per room (progress: steps_done / status).
final workflowRunsProvider = StreamProvider.family<List<AiWorkflowRun>, String>(
  (ref, roomId) {
    return ref.watch(aiWorkflowRepositoryProvider).watchRuns(roomId);
  },
);
