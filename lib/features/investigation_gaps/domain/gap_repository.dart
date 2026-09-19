// CaseThread Phase 5: Investigation gap repository contract.
import '../../../core/api/models.dart' show InvestigationGap;

abstract class GapRepository {
  Future<List<InvestigationGap>> list(String roomId);
  Future<InvestigationGap> create(String roomId, GapCreateInput input);
  Future<String> createTask(String gapId, String title, {String? description});
}

/// Input for creating an investigation gap.
class GapCreateInput {
  final String gapType;
  final String description;

  const GapCreateInput({required this.gapType, required this.description});
}
