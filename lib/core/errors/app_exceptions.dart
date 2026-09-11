/// Typed error hierarchy for the whole app (Rules.md §5): no bare
/// `throw Exception(...)` anywhere — the UI layer reacts to these types
/// with specific, actionable messages (Design.md §9).
///
/// Every feature-level error type extends [AppException] so the UI boundary
/// can render a human-readable message even for unexpected subtypes.
sealed class AppException implements Exception {
  const AppException({required this.message, this.cause});

  /// Human-readable message, safe to show directly in the UI — already
  /// phrased per Design.md §9 (specific, actionable, never blaming).
  final String message;

  /// The underlying error, if any. Never rendered raw to users; used for
  /// logging only (Rules.md §6).
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Supabase/credentials have not been configured for this runtime yet.
class AppNotConfiguredException extends AppException {
  const AppNotConfiguredException()
    : super(message: 'CaseThread is not connected to a backend yet.');
}

/// Any authentication failure (bad credentials, session loss).
class AuthException extends AppException {
  const AuthException({required super.message, super.cause});

  factory AuthException.fromSupabase(Object error) {
    return AuthException(
      message:
          'That email and password combination didn\'t match an account. '
          'Check the details and try again.',
      cause: error,
    );
  }
}

/// Email/password validation failure (client-side, before any network call).
class AuthValidationException extends AppException {
  const AuthValidationException({required super.message});
}

/// Network connectivity failure — actions should queue and retry where
/// feasible (PRD §6.7), this surfaces when they can't.
class NetworkException extends AppException {
  const NetworkException({super.cause})
    : super(message: 'Couldn\'t reach the server. Check your connection.');
}

/// A room access code was invalid or expired. Deliberately leaks no
/// information about whether the code ever existed (PRD §6.2).
class InvalidRoomCodeException extends AppException {
  const InvalidRoomCodeException()
    : super(
        message:
            'That code isn\'t valid. Ask the room owner for a '
            'current code.',
      );
}

/// The authenticated user's role is not permitted to perform the action.
/// Render with the user's actual role at the call site (PRD §6.7:
/// "Your role — Observer — can't upload evidence in this room").
class PermissionDeniedException extends AppException {
  const PermissionDeniedException({required String action})
    : super(message: 'Your role doesn\'t allow $action in this room.');
}

/// Requested room (or other entity) does not exist or is not visible.
class RoomNotFoundException extends AppException {
  const RoomNotFoundException() : super(message: 'That room isn\'t available.');
}

/// Unexpected failure that none of the above types describe. The UI shows
/// the generic message; `cause` is logged, never displayed (Rules.md §5).
class UnexpectedException extends AppException {
  const UnexpectedException({
    super.message = 'Something went wrong on our side. Please try again.',
    super.cause,
  });
}

/// Requested case type or role definition is unknown (config data).
class UnknownCaseTypeException extends AppException {
  const UnknownCaseTypeException(this.caseTypeId)
    : super(message: 'Case type "$caseTypeId" is not available.');
  final String caseTypeId;
}
