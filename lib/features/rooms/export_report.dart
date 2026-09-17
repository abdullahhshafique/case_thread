import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/error_mapper.dart';
import '../../core/api/models.dart' show Permission;
import '../auth/auth_providers.dart';
import 'room_permissions.dart';

/// The compiled case report (0015 export_case_report). The DB already
/// stripped everything the caller can't see — the client only renders.
class CaseReport {
  const CaseReport({required this.document});
  final Map<String, dynamic> document;

  String get roomName =>
      (document['room'] as Map<String, dynamic>)['name'] as String? ?? '';
  DateTime get generatedAt =>
      DateTime.parse(document['generated_at'] as String);

  /// Renders the report to Markdown (portable; opens as .md/.txt in any
  /// viewer — the "file it or share it outside" need from PRD P1).
  String toMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# Case Report — $roomName');
    buf.writeln();
    buf.writeln('Generated ${generatedAt.toLocal()} by CaseThread');
    buf.writeln();

    final room = document['room'] as Map<String, dynamic>;
    buf.writeln('**Case type:** ${room['case_type']}  ');
    buf.writeln('**Status:** ${room['status']}  ');
    buf.writeln('**Opened:** ${room['opened']}');
    buf.writeln();

    buf.writeln('## Members');
    for (final m in (document['members'] as List)) {
      final mm = m as Map<String, dynamic>;
      buf.writeln('- ${mm['name']} (${mm['role']})');
    }
    buf.writeln();

    buf.writeln('## Evidence');
    for (final e in (document['evidence'] as List)) {
      final em = e as Map<String, dynamic>;
      buf.writeln(
        '- ${em['filename']} (v${em['version']}, sha256 `${em['sha256']}`)',
      );
    }
    buf.writeln();

    buf.writeln('## Tasks');
    for (final t in (document['tasks'] as List)) {
      final tm = t as Map<String, dynamic>;
      final due = tm['due'] == null ? '' : ' — due ${tm['due']}';
      buf.writeln('- [${tm['status']}] ${tm['title']}$due');
    }
    buf.writeln();

    buf.writeln('## Timeline');
    for (final e in (document['timeline'] as List)) {
      final em = e as Map<String, dynamic>;
      final payload = em['payload'] as Map<String, dynamic>?;
      final summary = payload?['summary'] as String? ?? em['type'] as String;
      buf.writeln('- ${em['when']} — ${em['actor'] ?? 'System'}: $summary');
    }

    final status = document['investigation_status'] as String?;
    if (status != null) {
      buf.writeln();
      buf.writeln('**Investigation status:** $status');
    }

    buf.writeln();
    buf.writeln('## Contradictions');
    for (final c in (document['contradictions'] as List? ?? [])) {
      final cm = c as Map<String, dynamic>;
      buf.writeln(
        '- [${cm['status']}] ${cm['detail']} '
        '(flagged: ${cm['flagged_reason']})',
      );
    }
    buf.writeln();

    buf.writeln('## Alibis');
    for (final a in (document['alibis'] as List? ?? [])) {
      final am = a as Map<String, dynamic>;
      buf.writeln(
        '- [${am['status']}] ${am['claim']} '
        '(window: ${am['window_start']} – ${am['window_end']})',
      );
    }
    buf.writeln();

    buf.writeln('## Investigation Gaps');
    for (final g in (document['gaps'] as List? ?? [])) {
      final gm = g as Map<String, dynamic>;
      buf.writeln(
        '- [${gm['status']}] ${gm['description']} '
        '(type: ${gm['gap_type']})',
      );
    }
    return buf.toString();
  }
}

/// Export contract (Phase 2): compile + audit happen server-side (0015);
/// the client renders and saves.
abstract class ExportRepository {
  Future<CaseReport> exportRoom(String roomId);
}

class SupabaseExportRepository implements ExportRepository {
  SupabaseExportRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<CaseReport> exportRoom(String roomId) async {
    try {
      final response = await _client.rpc(
        'export_case_report',
        params: {'target_room': roomId},
      );
      return CaseReport(
        document: Map<String, dynamic>.from(
          jsonDecode(jsonEncode(response)) as Map,
        ),
      );
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final exportRepositoryProvider = Provider<ExportRepository>((ref) {
  return SupabaseExportRepository(ref.watch(supabaseClientProvider));
});

/// Whether the caller may export this room (UI gate; DB re-checks).
final canExportProvider = FutureProvider.family<bool, String>((ref, roomId) {
  return ref
      .watch(myRoomPermissionsProvider(roomId))
      .maybeWhen(
        data: (p) => p.can(Permission.exportReports),
        orElse: () => false,
      );
});
