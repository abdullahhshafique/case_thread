import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';

/// One version-history entry (0024): audit-derived, append-only by
/// construction (the audit log can't be rewritten — 0003).
class VersionEntry {
  const VersionEntry({
    required this.versionNo,
    required this.action,
    required this.detail,
    required this.changedAt,
    this.actorName,
  });

  final int versionNo;

  /// 'created' | 'edited' | 'status_changed'.
  final String action;

  /// Human summary of the change (e.g. '"A" → "B"').
  final String detail;
  final DateTime changedAt;
  final String? actorName;

  factory VersionEntry.fromMap(Map<String, dynamic> map) {
    return VersionEntry(
      versionNo: (map['version_no'] as num).toInt(),
      action: map['action'] as String,
      detail: (map['detail'] as String?) ?? '',
      changedAt: DateTime.parse(map['changed_at'] as String),
      actorName: map['actor_name'] as String?,
    );
  }
}

/// Version-history contract (0024): per-object change list over the
/// append-only audit log. RLS does the scoping (invoker rights).
abstract class VersionHistoryRepository {
  Future<List<VersionEntry>> listVersions(String objectKind, String objectId);
}

class SupabaseVersionHistoryRepository implements VersionHistoryRepository {
  SupabaseVersionHistoryRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<VersionEntry>> listVersions(
    String objectKind,
    String objectId,
  ) async {
    try {
      final rows = await _client.rpc(
        'list_versions',
        params: {'object_kind': objectKind, 'target_id': objectId},
      );
      return (rows as List)
          .map((row) => VersionEntry.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final versionHistoryRepositoryProvider = Provider<VersionHistoryRepository>((
  ref,
) {
  return SupabaseVersionHistoryRepository(ref.watch(supabaseClientProvider));
});

/// History for one object (used by the viewer sheet).
final objectVersionsProvider =
    FutureProvider.family<List<VersionEntry>, (String, String)>((ref, args) {
      final (kind, id) = args;
      return ref.watch(versionHistoryRepositoryProvider).listVersions(kind, id);
    });
