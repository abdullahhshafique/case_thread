import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../../core/api/models.dart';
import './data/supabase_contradiction_repository.dart';
import './domain/contradiction_repository.dart';

final contradictionRepositoryProvider = Provider<ContradictionRepository>((
  ref,
) {
  return SupabaseContradictionRepository(ref.watch(supabaseClientProvider));
});

final contradictionListProvider =
    FutureProvider.family<List<Contradiction>, String>(
      (ref, roomId) => ref.watch(contradictionRepositoryProvider).list(roomId),
    );
