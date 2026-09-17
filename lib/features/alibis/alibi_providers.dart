import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../auth/auth_providers.dart';
import './data/supabase_alibi_repository.dart';
import './domain/alibi_repository.dart';

final alibiRepositoryProvider = Provider<AlibiRepository>((ref) {
  return SupabaseAlibiRepository(ref.watch(supabaseClientProvider));
});

final alibiListProvider = FutureProvider.family<List<Alibi>, String>(
  (ref, roomId) => ref.watch(alibiRepositoryProvider).list(roomId),
);
