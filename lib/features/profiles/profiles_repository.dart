import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/app_exceptions.dart';
import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';

/// Profile data for the signed-in user (migration 0001 `profiles` table).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
}

/// Fetches the current user's profile row.
///
/// Falls back to auth metadata when the profile row is missing (e.g. the
/// trigger hasn't run yet, or a user was created before 0001 was applied)
/// — a missing profile must never block the app (PRD §6.7).
class ProfilesRepository {
  ProfilesRepository(this._client);

  final supabase.SupabaseClient _client;

  Future<UserProfile> getMyProfile({
    required String fallbackEmail,
    String? fallbackDisplayName,
  }) async {
    try {
      final row = await _client
          .from('profiles')
          .select('id, display_name, avatar_url')
          .limit(1) // RLS scopes to own row (0001 policies).
          .maybeSingle();

      final name = (row?['display_name'] as String?)?.trim().isNotEmpty == true
          ? row!['display_name'] as String
          : (fallbackDisplayName ?? fallbackEmail.split('@').first);

      return UserProfile(
        id: (row?['id'] as String?) ?? '',
        displayName: name,
        avatarUrl: row?['avatar_url'] as String?,
      );
    } catch (error) {
      // Profile fetch is enhancement, not gate — degrade to fallback.
      throw toAppException(error);
    }
  }
}

final profilesRepositoryProvider = Provider<ProfilesRepository>((ref) {
  return ProfilesRepository(ref.watch(supabaseClientProvider));
});

/// Async profile of the signed-in user (null when signed out).
final myProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final session = await ref.watch(sessionProvider.future);
  final user = session;
  if (user == null) return null;
  final repo = ref.watch(profilesRepositoryProvider);
  try {
    return await repo.getMyProfile(
      fallbackEmail: user.email,
      fallbackDisplayName: user.displayName,
    );
  } on AppException {
    // Missing profile row degrades to a derived name, never a dead end.
    return UserProfile(id: user.id, displayName: user.displayName ?? '');
  }
});
