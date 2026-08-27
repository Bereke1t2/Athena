import 'package:athena/core/error/failure.dart';
import 'package:athena/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('failureFromDio', () {
    test('connection errors map to network failure', () {
      final f = failureFromDio(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      ));
      expect(f, isA<NetworkFailure>());
    });

    test('timeouts map to timeout failure', () {
      final f = failureFromDio(DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.receiveTimeout,
      ));
      expect(f, isA<TimeoutFailure>());
    });

    test('404 parses not-found envelope', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 404,
        data: {
          'error': {'code': 'not_found', 'message': 'paper not found'}
        },
      );
      final f = failureFromDio(DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.badResponse,
        response: response,
      ));
      final nf = f as NotFoundFailure;
      expect(nf.message, 'paper not found');
    });

    test('400 parses validation details', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 400,
        data: {
          'error': {
            'code': 'invalid_request',
            'message': 'bad query',
            'details': [
              {'field': 'limit', 'issue': 'must be <= 100'},
            ],
          }
        },
      );
      final f = failureFromDio(DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.badResponse,
        response: response,
      ));
      final vf = f as ValidationFailure;
      expect(vf.fieldIssues, contains('limit: must be <= 100'));
    });

    test('500 maps to server failure with status', () {
      final response = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/'),
        statusCode: 500,
        data: {
          'error': {'code': 'internal', 'message': 'boom'}
        },
      );
      final f = failureFromDio(DioException(
        requestOptions: response.requestOptions,
        type: DioExceptionType.badResponse,
        response: response,
      ));
      final sf = f as ServerFailure;
      expect(sf.statusCode, 500);
      expect(sf.code, 'internal');
    });

    test('non-dio errors map to unknown', () {
      expect(failureFromDio(StateError('x')), isA<UnknownFailure>());
    });
  });
}
