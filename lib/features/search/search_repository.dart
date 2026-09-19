import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/errors/error_mapper.dart';
import '../auth/auth_providers.dart';

/// One search hit (0022): where it landed + a redaction-aware snippet.
class SearchHit {
  const SearchHit({
    required this.roomId,
    required this.roomName,
    required this.caseType,
    required this.objectType,
    required this.snippet,
    required this.createdAt,
  });

  final String roomId;
  final String roomName;
  final String caseType;

  /// 'room' | 'discussion' | 'timeline' | 'task' | 'evidence'.
  final String objectType;

  /// Matched text — already stripped of privileged fields server-side
  /// (v_timeline redaction runs inside the search, 0022).
  final String snippet;
  final DateTime createdAt;

  factory SearchHit.fromMap(Map<String, dynamic> map) {
    return SearchHit(
      roomId: map['room_id'] as String,
      roomName: map['room_name'] as String,
      caseType: map['case_type'] as String,
      objectType: map['object_type'] as String,
      snippet: (map['snippet'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Cross-case search contract (0022): one RPC, RLS does the scoping —
/// the same rows the caller could SELECT are the only rows searched.
abstract class SearchRepository {
  Future<List<SearchHit>> search(String query);
}

class SupabaseSearchRepository implements SearchRepository {
  SupabaseSearchRepository(this._client);

  final supabase.SupabaseClient _client;

  @override
  Future<List<SearchHit>> search(String query) async {
    try {
      final rows = await _client.rpc('search_cases', params: {'query': query});
      return (rows as List)
          .map((row) => SearchHit.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (error) {
      throw toAppException(error);
    }
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SupabaseSearchRepository(ref.watch(supabaseClientProvider));
});

/// Live query state for the search screen. Kept as a plain notifier so
/// debouncing lives in the UI (one timer, no provider churn per key).
class SearchQueryState {
  const SearchQueryState({this.query = '', this.hits = const [], this.error});

  final String query;
  final List<SearchHit> hits;

  /// Last search failure message (typed, UI-safe); null when healthy.
  final String? error;
}

class SearchQueryNotifier extends Notifier<SearchQueryState> {
  @override
  SearchQueryState build() => const SearchQueryState();

  Future<void> run(String query) async {
    if (query.trim().length < 2) {
      state = SearchQueryState(query: query);
      return;
    }
    state = SearchQueryState(query: query, hits: state.hits);
    try {
      final hits = await ref.read(searchRepositoryProvider).search(query);
      state = SearchQueryState(query: query, hits: hits);
    } on Exception catch (error) {
      // Typed errors carry user-safe messages; keep old hits visible.
      state = SearchQueryState(
        query: query,
        hits: state.hits,
        error: toAppException(error).message,
      );
    }
  }
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, SearchQueryState>(
      SearchQueryNotifier.new,
    );
