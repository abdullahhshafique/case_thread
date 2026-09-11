import 'models.dart';

/// Contract for the config data every room flow needs: case types and
/// their role definitions (seeds from migration 0004).
///
/// Supabase implementation arrives with the rooms feature (Sprint 3);
/// the interface + fake exist now so Sprint 3 code compiles against the
/// contract rather than the wire format (Architecture.md §2).
abstract class CaseTypeRepository {
  /// Active case types available at room creation (PRD §6.1).
  Future<List<CaseType>> getActiveCaseTypes();

  /// Roles defined for a case type — feeds the join-flow role picker
  /// (PRD §6.2).
  Future<List<RoleDefinition>> getRolesForCaseType(String caseTypeId);
}
