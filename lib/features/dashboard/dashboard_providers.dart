import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
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
