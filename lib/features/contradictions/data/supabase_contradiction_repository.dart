import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/models.dart' show Contradiction;
import '../../../core/errors/error_mapper.dart';
import '../domain/contradiction_repository.dart';

class SupabaseContradictionRepository implements ContradictionRepository {
  SupabaseContradictionRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<Contradiction>> list(String roomId) async {
    final rows = await _client
        .from('contradictions')
        .select(
          'id, room_id, source_type, ai_suggestion_id, conflicting_detail, '
          'relevant_time, relevant_location, flagged_reason, status, '
          'resolution_note, linked_task_id, flagged_by, resolved_by, '
          'created_at, resolved_at',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Contradiction.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<Contradiction> create(
    String roomId,
    ContradictionCreateInput input,
  ) async {
    try {
      // Insert the contradiction first (manual path).
      final row = await _client
          .from('contradictions')
          .insert({
            'room_id': roomId,
            'source_type': 'manual',
            'conflicting_detail': input.conflictingDetail,
            'flagged_reason': input.flaggedReason,
            'relevant_time': input.relevantTime?.toIso8601String(),
            'relevant_location': input.relevantLocation,
            'flagged_by': _client.auth.currentUser?.id,
          })
          .select()
          .single();

      // Insert sources (each conflicting item).
      for (final sourceId in input.sourceIds) {
        // Determine source type from ID format — for simplicity,
        // we insert as evidence_item_id. The app layer knows
        // which table each ID belongs to.
        await _client.from('contradiction_sources').insert({
          'contradiction_id': row['id'],
          'evidence_item_id': sourceId,
        });
      }

      return Contradiction.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> decide(
    String contradictionId,
    ContradictionDecisionInput input,
  ) async {
    try {
      await _client.rpc(
        'contradiction_decision',
        params: {
          'p_contradiction_id': contradictionId,
          'p_decision': input.decision,
          'p_resolution_note': input.resolutionNote ?? '',
          'p_linked_task_id': input.linkedTaskId,
        },
      );
    } catch (error) {
      throw toAppException(error);
    }
  }
}
