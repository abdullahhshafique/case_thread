// CaseThread Phase 5: Alibi repository contract.
import '../../../core/api/models.dart' show Alibi, AlibiStatus;

abstract class AlibiRepository {
  Future<List<Alibi>> list(String roomId);
  Future<Alibi> create(String roomId, AlibiCreateInput input);
  Future<void> verify(String alibiId, AlibiVerifyInput input);
}

/// Input for creating an alibi claim.
class AlibiCreateInput {
  final String entityId;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String claimText;
  final String source;

  const AlibiCreateInput({
    required this.entityId,
    required this.windowStart,
    required this.windowEnd,
    required this.claimText,
    this.source = '',
  });
}

/// Input for verifying an alibi.
class AlibiVerifyInput {
  final AlibiStatus status;
  final String statusReason;
  final List<String> evidenceItemIds;
  final List<String> timelineEventIds;

  const AlibiVerifyInput({
    required this.status,
    required this.statusReason,
    this.evidenceItemIds = const [],
    this.timelineEventIds = const [],
  });
}
