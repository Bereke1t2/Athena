import 'failure.dart';

/// Centralized user-facing messages (conventions: no inline strings scattered
/// across screens).
extension FailureMessage on Failure {
  String get message => switch (this) {
        NetworkFailure() =>
          'No connection. Check your network and try again.',
        TimeoutFailure() => 'The server took too long to respond.',
        NotFoundFailure(:final message) =>
          message ?? 'That content could not be found.',
        ValidationFailure(:final message, :final fieldIssues) =>
          [message, ...fieldIssues].where((s) => s.isNotEmpty).join('\n'),
        ServerFailure(:final statusCode, :final message) =>
          message ?? (statusCode == 429
              ? 'Service is busy. Please retry in a few seconds.'
              : 'Something went wrong${statusCode != null ? ' (error $statusCode)' : ''}. Please try again.'),
        UnknownFailure() => 'Unexpected error. Please try again.',
      };
}
