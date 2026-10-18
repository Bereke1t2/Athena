import 'auth_models.dart';

abstract class AuthRepository {
  Future<({String token, UserProfile user})> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<({String token, UserProfile user})> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<UserProfile> getCurrentUser();
}
