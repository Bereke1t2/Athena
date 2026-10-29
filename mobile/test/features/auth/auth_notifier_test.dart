import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/auth/domain/auth_models.dart';
import 'package:athena/features/auth/domain/auth_repository.dart';
import 'package:athena/features/auth/presentation/auth_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthRepository implements AuthRepository {
  bool shouldFail = false;

  @override
  Future<({String token, UserProfile user})> login({required String email, required String password}) async {
    if (shouldFail) {
      throw Exception('Invalid credentials');
    }
    return (
      token: 'jwt-token-123',
      user: UserProfile(
        id: 'u1',
        email: email,
        displayName: 'Test User',
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  @override
  Future<({String token, UserProfile user})> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return (
      token: 'jwt-token-456',
      user: UserProfile(
        id: 'u2',
        email: email,
        displayName: displayName,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    return UserProfile(
      id: 'u1',
      email: 'test@example.com',
      displayName: 'Test User',
      createdAt: DateTime.utc(2026, 1, 1),
    );
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<String> forgotPassword(String email) async => 'Password recovery email dispatched.';

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {}
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.clearAuthSession();
    await UserPreferences.instance.load();
  });

  test('auth notifier initial state is unauthenticated when no token saved', () {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.token, isNull);
    expect(state.user, isNull);
  });

  test('auth notifier login succeeds and sets authenticated state', () async {
    final fake = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    final ok = await notifier.login(email: 'test@example.com', password: 'secretpassword');

    expect(ok, isTrue);
    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.token, 'jwt-token-123');
    expect(state.user?.email, 'test@example.com');
  });

  test('auth notifier login failure sets errorMessage', () async {
    final fake = FakeAuthRepository()..shouldFail = true;
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    final ok = await notifier.login(email: 'bad@example.com', password: 'wrong');

    expect(ok, isFalse);
    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.errorMessage, isNotNull);
  });

  test('auth notifier deleteAccount clears auth session', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    await notifier.login(email: 'test@example.com', password: 'password');
    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);

    await notifier.deleteAccount();
    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
  });

  test('auth notifier forgotPassword and resetPassword dispatch successfully', () async {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authNotifierProvider.notifier);
    final msg = await notifier.forgotPassword('user@example.com');
    expect(msg, equals('Password recovery email dispatched.'));

    final resetOk = await notifier.resetPassword(token: 'token-123', newPassword: 'new-password-123');
    expect(resetOk, isTrue);
  });
}
