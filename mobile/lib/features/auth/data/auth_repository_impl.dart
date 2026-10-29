import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import 'auth_dtos.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<({String token, UserProfile user})> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'display_name': displayName,
        },
      );
      final dto = SessionResponseDto.fromJson(res.data!);
      return (token: dto.token, user: dto.user.toDomain());
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<({String token, UserProfile user})> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      final dto = SessionResponseDto.fromJson(res.data!);
      return (token: dto.token, user: dto.user.toDomain());
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } catch (e) {
      // Best-effort logout on the server
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      await _dio.delete<void>('/me');
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me');
      final dto = UserDto.fromJson(res.data!);
      return dto.toDomain();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<String> forgotPassword(String email) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/forgot-password',
        data: {'email': email},
      );
      return res.data?['message'] as String? ?? 'Password recovery email dispatched.';
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/auth/reset-password',
        data: {'token': token, 'new_password': newPassword},
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
