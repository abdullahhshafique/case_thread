import 'package:flutter/foundation.dart';

import 'app_exceptions.dart';

/// Maps any thrown object to a typed [AppException] (Rules.md §5: typed
/// errors, always — nothing crosses a boundary as a raw exception).
AppException toAppException(Object error) {
  final mapped = switch (error) {
    AppException e => e,
    // supabase AuthApiException shares its name with our type, so match on
    // runtimeType string to avoid importing the SDK into every call site.
    _ when error.runtimeType.toString() == 'AuthApiException' =>
      AuthException.fromSupabase(error),
    _ => null,
  };
  if (mapped != null) return mapped;
  // Unmapped error: the user sees the calm generic message, but the real
  // cause prints here so console output can be pasted for diagnosis.
  debugPrint('CaseThread unmapped error → generic: $error');
  return UnexpectedException(cause: error);
}
