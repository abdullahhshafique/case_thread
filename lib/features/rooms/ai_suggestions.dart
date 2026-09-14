import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/api/models.dart' show Permission;
import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';
import 'room_permissions.dart';

/// An AI suggestion (Phase 3) — ALWAYS pending human review before it
/// can touch the case record (Rules.md §11).
class AiSuggestion {
  const AiSuggestion({
    required this.id,
    required this.roomId,
    required this.agentType,
    required this.status,
    required this.createdAt,
    this.title,
    this.detail,
    this.provider,
    this.reviewedAt,
  });

  final String id;
  final String roomId;
  final String agentType;

  /// pending | accepted | edited | dismissed.
  final String status;
  final String? title;
  final String? detail;
  final String? provider;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';

  factory AiSuggestion.fromMap(Map<String, dynamic> map) {
    final output = map['output'];
    Map<String, dynamic> out = output is Map<String, dynamic>
        ? output
        : const {};
    return AiSuggestion(
      id: map['id'] as String,
      roomId: map['room_id'] as String,
      agentType: map['agent_type'] as String,
      status: map['status'] as String,
      title: out['title'] as String?,
      detail: out['detail'] as String?,
      provider: out['provider'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      reviewedAt: map['reviewed_at'] == null
          ? null
          : DateTime.tryParse(map['reviewed_at'] as String),
    );
  }
}

/// An agent the room can run (from the 0017 config registry).
class AgentDefinition {
  const AgentDefinition({
    required this.id,
    required this.displayName,
    required this.description,
    required this.caseType,
  });

  final String id;
  final String displayName;
  final String description;
  final String? caseType;

  factory AgentDefinition.fromMap(Map<String, dynamic> map) {
    return AgentDefinition(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      description: map['description'] as String? ?? '',
      caseType: map['case_type'] as String?,
    );
  }
}

/// Phase 3 contract: trigger agents (Edge Function, permission-gated),
/// review suggestions (review_suggestion RPC, Lead-tier only).
abstract class AiAgentRepository {
  /// Agents available for the room's case type (plus case-type-agnostic).
  Future<List<AgentDefinition>> listAgents(String caseTypeId);

  /// Room suggestions, newest first.
  Future<List<AiSuggestion>> listSuggestions(String roomId);

  /// Realtime suggestion stream (0018 added ai_suggestions to the
  /// supabase_realtime publication — pending findings push live,
  /// Architecture.md §7).
  Stream<List<AiSuggestion>> watchSuggestions(String roomId);

  /// Runs an agent via the Edge Function. Returns the new suggestion id,
  /// or null when the provider found nothing worth flagging.
  Future<String?> runAgent({required String roomId, required String agentId});

  /// Lead-tier review: accept/edited/dismiss (0017 RPC — atomic
  /// timeline + audit on promotion).
  Future<void> reviewSuggestion({
    required String suggestionId,
    required String decision,
    Map<String, dynamic>? editedOutput,
  });
}

class SupabaseAiAgentRepository implements AiAgentRepository {
  SupabaseAiAgentRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<AgentDefinition>> listAgents(String caseTypeId) async {
    final rows = await _client
        .from('ai_agents')
        .select('id, display_name, description, case_type')
        .eq('is_active', true)
        .or('case_type.is.null,case_type.eq.$caseTypeId')
        .order('display_name');
    return (rows as List)
        .map((r) => AgentDefinition.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<List<AiSuggestion>> listSuggestions(String roomId) async {
    final rows = await _client
        .from('ai_suggestions')
        .select(
          'id, room_id, agent_type, status, output, created_at, reviewed_at',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => AiSuggestion.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Stream<List<AiSuggestion>> watchSuggestions(String roomId) {
    // Same .stream() pattern as discussion/tasks: RLS-scoped channel,
    // rows mapped to models. Status flips (review decisions) also push.
    return _client
        .from('ai_suggestions')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map(
          (rows) => rows
              .map((r) => AiSuggestion.fromMap(Map<String, dynamic>.from(r)))
              .toList()
              .reversed
              .toList(), // newest first in UI
        );
  }

  @override
  Future<String?> runAgent({
    required String roomId,
    required String agentId,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'ai-agent',
        body: {'agent_id': agentId, 'room_id': roomId},
      );
      final data = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(response.data)) as Map,
      );
      if (data['status'] == 'no_findings') return null;
      if (data['status'] == 'suggestion_created') {
        return data['suggestion_id'] as String;
      }
      if (data['code'] == 'forbidden') {
        throw Exception(data['message']);
      }
      throw Exception('The agent run failed. Try again.');
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> reviewSuggestion({
    required String suggestionId,
    required String decision,
    Map<String, dynamic>? editedOutput,
  }) async {
    try {
      await _client.rpc(
        'review_suggestion',
        params: {
          'suggestion': suggestionId,
          'decision': decision,
          'edited_output': editedOutput,
        },
      );
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final aiAgentRepositoryProvider = Provider<AiAgentRepository>((ref) {
  return SupabaseAiAgentRepository(ref.watch(supabaseClientProvider));
});

/// Agents registry for a case type.
final agentsProvider = FutureProvider.family<List<AgentDefinition>, String>((
  ref,
  caseTypeId,
) {
  return ref.watch(aiAgentRepositoryProvider).listAgents(caseTypeId);
});

/// Suggestions per room — realtime (pending findings push live the
/// moment the Edge Function inserts them; review flips stream too).
final suggestionsProvider = StreamProvider.family<List<AiSuggestion>, String>((
  ref,
  roomId,
) {
  return ref.watch(aiAgentRepositoryProvider).watchSuggestions(roomId);
});

/// Lead-tier gating for review actions (UI hides; DB enforces).
final canReviewAiProvider = FutureProvider.family<bool, String>((ref, roomId) {
  return ref
      .watch(myRoomPermissionsProvider(roomId))
      .maybeWhen(
        data: (p) => p.can(Permission.approveAiFindings),
        orElse: () => false,
      );
});
