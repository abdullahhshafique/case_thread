import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/models.dart'
    show Alibi, AlibiStatus;
import '../../../core/errors/error_mapper.dart';
import '../domain/alibi_repository.dart';

class SupabaseAlibiRepository implements AlibiRepository {
  SupabaseAlibiRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<Alibi>> list(String roomId) async {
    final rows = await _client
        .from('alibis')
        .select(
          'id, room_id, entity_id, claimed_window_start, claimed_window_end, '
          'claim_text, source, status, status_reason, created_by, verified_by, '
          'created_at, verified_at',
        )
        .eq('room_id', roomId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Alibi.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  @override
  Future<Alibi> create(String roomId, AlibiCreateInput input) async {
    try {
      final row = await _client
          .from('alibis')
          .insert({
            'room_id': roomId,
            'entity_id': input.entityId,
            'claimed_window_start': input.windowStart.toIso8601String(),
            'claimed_window_end': input.windowEnd.toIso8601String(),
            'claim_text': input.claimText,
            'source': input.source,
            'created_by': _client.auth.currentUser?.id,
          })
          .select()
          .single();
      return Alibi.fromMap(Map<String, dynamic>.from(row));
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<void> verify(String alibiId, AlibiVerifyInput input) async {
    // SQL CHECK values are snake_case; the Dart enum is camelCase.
    final status = switch (input.status) {
      AlibiStatus.partiallyVerified => 'partially_verified',
      AlibiStatus.conflict => 'conflict',
      AlibiStatus.insufficientData => 'insufficient_data',
      AlibiStatus.verified => 'verified',
    };
    try {
      await _client.rpc(
        'verify_alibi',
        params: {
          'p_alibi_id': alibiId,
          'p_status': status,
          'p_status_reason': input.statusReason,
          'p_evidence_item_ids': input.evidenceItemIds,
          'p_timeline_event_ids': input.timelineEventIds,
        },
      );
    } catch (error) {
      throw toAppException(error);
    }
  }
}
