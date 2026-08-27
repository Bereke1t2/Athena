import 'package:freezed_annotation/freezed_annotation.dart';

part 'failure.freezed.dart';

/// Sealed failure hierarchy crossing into presentation (mobile-conventions:
/// no raw exceptions above the data layer).
@freezed
sealed class Failure with _$Failure {
  const factory Failure.network() = NetworkFailure;

  const factory Failure.timeout() = TimeoutFailure;

  const factory Failure.notFound({String? message}) = NotFoundFailure;

  const factory Failure.validation({
    required String message,
    @Default(<String>[]) List<String> fieldIssues,
  }) = ValidationFailure;

  const factory Failure.server({
    required int? statusCode,
    String? code,
    String? message,
  }) = ServerFailure;

  const factory Failure.unknown({Object? cause}) = UnknownFailure;
}
