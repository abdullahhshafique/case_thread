import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/app_exceptions.dart';
import '../../features/auth/auth_providers.dart';
import 'case_type_repository.dart';
import 'models.dart';

/// Supabase-backed [CaseTypeRepository]. Reads `case_types` / `roles`
/// via PostgREST — both are readable by any authenticated user per the
/// 0005 RLS policies.
class SupabaseCaseTypeRepository implements CaseTypeRepository {
  SupabaseCaseTypeRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<CaseType>> getActiveCaseTypes() async {
    final rows = await _client
        .from('case_types')
        .select('id, display_name, description, is_active')
        .eq('is_active', true)
        .order('display_name');

    return (rows as List)
        .map((row) => CaseType.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<List<RoleDefinition>> getRolesForCaseType(String caseTypeId) async {
    final rows = await _client
        .from('roles')
        .select('id, case_type, display_name, is_lead_tier, permissions')
        .eq('case_type', caseTypeId)
        .order('display_name');

    if (rows.isEmpty) {
      throw UnknownCaseTypeException(caseTypeId);
    }
    return rows
        .map((row) => RoleDefinition.fromMap(Map<String, dynamic>.from(row)))
        .toList();
  }
}

/// Provider (kept beside the implementation; auth_providers holds the
/// client provider this depends on).
final caseTypeRepositoryProvider = Provider<CaseTypeRepository>((ref) {
  return SupabaseCaseTypeRepository(ref.watch(supabaseClientProvider));
});
