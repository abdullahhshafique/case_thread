// CaseThread Phase 5: Dashboard repository contract.
import '../../../core/api/models.dart' show CaseClosedSummary, CaseStatistics;

abstract class DashboardRepository {
  Future<CaseStatistics> statistics(String roomId);
  Future<CaseClosedSummary?> closedSummary(String roomId);
}
