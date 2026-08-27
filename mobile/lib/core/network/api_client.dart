import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/app_constants.dart';
import '../error/failure.dart';

part 'api_client.g.dart';

/// The single dio instance (mobile-conventions: one client from core/network;
/// features declare typed endpoint methods against it).
@riverpod
Dio apiClient(Ref ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: Timeouts.connect,
      receiveTimeout: Timeouts.receive,
      responseType: ResponseType.json,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Request-ID'] = _newRequestId();
        handler.next(options);
      },
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }
  ref.onDispose(dio.close);
  return dio;
}

String _newRequestId() {
  final rng = Random();
  return List.generate(12, (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Maps dio failures onto the sealed [Failure] hierarchy, parsing the
/// backend's RFC-7807-style error envelope when present.
Failure failureFromDio(Object error) {
  if (error is! DioException) {
    return Failure.unknown(cause: error);
  }
  switch (error.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
      return const Failure.network();
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return const Failure.timeout();
    case DioExceptionType.badCertificate:
    case DioExceptionType.cancel:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.unknown:
      return Failure.unknown(cause: error);
    case DioExceptionType.badResponse:
      return _failureFromResponse(error.response);
  }
}

Failure _failureFromResponse(Response<dynamic>? response) {
  final status = response?.statusCode;
  final body = response?.data;
  String? code;
  String? message;
  final issues = <String>[];
  if (body is Map<String, dynamic>) {
    final err = body['error'];
    if (err is Map<String, dynamic>) {
      code = err['code'] as String?;
      message = err['message'] as String?;
      final details = err['details'];
      if (details is List) {
        for (final d in details) {
          if (d is Map<String, dynamic>) {
            issues.add('${d['field'] ?? ''}: ${d['issue'] ?? ''}'.trim());
          }
        }
      }
    }
  }

  switch (status) {
    case 404:
      return Failure.notFound(message: message);
    case 400:
      return Failure.validation(message: message ?? 'invalid request', fieldIssues: issues);
    case 429:
      return Failure.server(statusCode: 429, code: code, message: message ?? 'Service is busy, please retry.');
    default:
      return Failure.server(statusCode: status, code: code, message: message);
  }
}
