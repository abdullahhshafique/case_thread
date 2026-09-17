import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../../core/api/models.dart';
import './data/supabase_gap_repository.dart';
import './domain/gap_repository.dart';

final gapRepositoryProvider = Provider<GapRepository>((ref) {
  return SupabaseGapRepository(ref.watch(supabaseClientProvider));
});

final gapListProvider = FutureProvider.family<List<InvestigationGap>, String>(
  (ref, roomId) => ref.watch(gapRepositoryProvider).list(roomId),
);
