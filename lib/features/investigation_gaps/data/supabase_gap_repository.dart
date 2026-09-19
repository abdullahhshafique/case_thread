import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/models.dart' show InvestigationGap;
import '../../../core/errors/error_mapper.dart';
import '../domain/gap_repository.dart';

class SupabaseGapRepository implements GapRepository {
  SupabaseGapRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<InvestigationGap>> list(String roomId) async {
    final rows = await _client
        .from('investigation_gaps')
        .select(
          'id, room_id, gap_type, description, source_type, ai_suggestion_id, '
          'status, linked_task_id, created_by, created_at, resolved_at',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => InvestigationGap.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<InvestigationGap> create(String roomId, GapCreateInput input) async {
    try {
      final row = await _client
          .from('investigation_gaps')
          .insert({
            'room_id': roomId,
            'gap_type': input.gapType,
            'description': input.description,
            'source_type': 'manual',
            'created_by': _client.auth.currentUser?.id,
          })
          .select()
          .single();
      return InvestigationGap.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<String> createTask(
    String gapId,
    String title, {
    String? description,
  }) async {
    try {
      final result = await _client.rpc(
        'gap_create_task',
        params: {
          'p_gap_id': gapId,
          'p_task_title': title,
          'p_task_description': description ?? '',
        },
      );
      return result as String;
    } catch (error) {
      throw toAppException(error);
    }
  }
}
