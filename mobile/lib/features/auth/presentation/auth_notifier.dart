import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/prefs/user_preferences.dart';
import '../domain/auth_models.dart';

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _initSession();
  }

  final dynamic _repo;

  void _initSession() {
    final token = UserPreferences.instance.authToken;
    final id = UserPreferences.instance.userId;
    final email = UserPreferences.instance.userEmail;
    final displayName = UserPreferences.instance.userDisplayName;

    if (token != null && id != null && email != null) {
      state = state.copyWith(
        token: token,
        user: UserProfile(
          id: id,
          email: email,
          displayName: displayName ?? email.split('@').first,
          createdAt: DateTime.now(),
        ),
      );
      // Fetch fresh profile in background
      _refreshProfile();
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final user = await _repo.getCurrentUser();
      state = state.copyWith(user: user);
    } catch (_) {
      // Ignored: keep cached session
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repo.login(email: email, password: password);
      await UserPreferences.instance.saveAuthSession(
        token: res.token,
        id: res.user.id,
        email: res.user.email,
        displayName: res.user.displayName,
      );
      state = state.copyWith(
        token: res.token,
        user: res.user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repo.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      await UserPreferences.instance.saveAuthSession(
        token: res.token,
        id: res.user.id,
        email: res.user.email,
        displayName: res.user.displayName,
      );
      state = state.copyWith(
        token: res.token,
        user: res.user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.logout();
    } catch (_) {}
    await UserPreferences.instance.clearAuthSession();
    state = const AuthState();
  }
}
