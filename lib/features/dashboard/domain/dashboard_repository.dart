// CaseThread Phase 5: Dashboard repository contract.
import '../../../core/api/models.dart'
    show CaseBreakdown, CaseClosedSummary, CaseStatistics;

abstract class DashboardRepository {
  Future<CaseStatistics> statistics(String roomId);
  Future<CaseClosedSummary?> closedSummary(String roomId);

  /// Evidence-by-type + events-per-day for the dashboard graphs (0033).
  Future<CaseBreakdown> breakdown(String roomId);
}
