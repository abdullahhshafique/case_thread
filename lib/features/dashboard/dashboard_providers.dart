import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart'
    show CaseBreakdown, CaseClosedSummary, CaseStatistics;
import '../auth/auth_providers.dart';
import './data/supabase_dashboard_repository.dart';
import './domain/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return SupabaseDashboardRepository(ref.watch(supabaseClientProvider));
});

final dashboardStatsProvider = FutureProvider.family<CaseStatistics, String>(
  (ref, roomId) => ref.watch(dashboardRepositoryProvider).statistics(roomId),
);

final dashboardClosedSummaryProvider =
    FutureProvider.family<CaseClosedSummary?, String>(
      (ref, roomId) =>
          ref.watch(dashboardRepositoryProvider).closedSummary(roomId),
    );

/// Evidence-type + events-per-day breakdown for the graphs (0033).
final dashboardBreakdownProvider = FutureProvider.family<CaseBreakdown, String>(
  (ref, roomId) {
    ref.watch(sessionProvider);
    return ref.watch(dashboardRepositoryProvider).breakdown(roomId);
  },
);
