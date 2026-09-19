import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/api/models.dart'
    show CaseBreakdown, CaseClosedSummary, CaseStatistics;
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/app_exceptions.dart';
import '../domain/dashboard_repository.dart';

class SupabaseDashboardRepository implements DashboardRepository {
  SupabaseDashboardRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<CaseStatistics> statistics(String roomId) async {
    try {
      final result = await _client.rpc('v_case_statistics');
      // The view returns rows scoped by RLS — filter client-side
      // for the requested room.
      final rows = result as List;
      final match = rows.cast<Map<String, dynamic>>().firstWhere(
        (r) => r['room_id'] == roomId,
        orElse: () => {},
      );
      if (match.isEmpty) {
        // Room not visible to caller — RLS blocked it.
        throw const RoomNotFoundException();
      }
      return CaseStatistics.fromMap(match);
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<CaseBreakdown> breakdown(String roomId) async {
    try {
      final result = await _client.rpc(
        'v_case_breakdown',
        params: {'target_room': roomId},
      );
      return CaseBreakdown.fromMap(Map<String, dynamic>.from(result as Map));
    } catch (error) {
      throw toAppException(error);
    }
  }

  @override
  Future<CaseClosedSummary?> closedSummary(String roomId) async {
    try {
      final rows = await _client
          .from('case_closed_summaries')
          .select('id, room_id, summary_json, generated_at, generated_by')
          .eq('room_id', roomId)
          .order('generated_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return CaseClosedSummary.fromMap(Map<String, dynamic>.from(rows.first));
    } catch (error) {
      throw toAppException(error);
    }
  }
}
