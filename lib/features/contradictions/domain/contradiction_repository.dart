// CaseThread Phase 5: Contradiction repository contract.
import '../../../core/api/models.dart' show Contradiction;

abstract class ContradictionRepository {
  Future<List<Contradiction>> list(String roomId);
  Future<Contradiction> create(String roomId, ContradictionCreateInput input);
  Future<void> decide(String contradictionId, ContradictionDecisionInput input);
}

/// Input for manually flagging a contradiction.
class ContradictionCreateInput {
  final List<String> sourceIds; // evidence / timeline / alibi ids
  final String conflictingDetail;
  final String flaggedReason;
  final DateTime? relevantTime;
  final String? relevantLocation;

  const ContradictionCreateInput({
    required this.sourceIds,
    required this.conflictingDetail,
    required this.flaggedReason,
    this.relevantTime,
    this.relevantLocation,
  });
}

/// Input for resolving/dismissing a contradiction.
class ContradictionDecisionInput {
  final String decision; // 'resolve' | 'dismiss'
  final String? resolutionNote;
  final String? linkedTaskId;

  const ContradictionDecisionInput({
    required this.decision,
    this.resolutionNote,
    this.linkedTaskId,
  });
}
