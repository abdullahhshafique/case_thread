import 'app_exceptions.dart';

/// Maps any thrown object to a typed [AppException] (Rules.md §5: typed
/// errors, always — nothing crosses a boundary as a raw exception).
AppException toAppException(Object error) {
  return switch (error) {
    AppException e => e,
    // supabase AuthApiException shares its name with our type, so match on
    // runtimeType string to avoid importing the SDK into every call site.
    _ when error.runtimeType.toString() == 'AuthApiException' =>
      AuthException.fromSupabase(error),
    _ => UnexpectedException(cause: error),
  };
}
