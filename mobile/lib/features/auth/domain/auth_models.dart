library;

/// Domain representation of an authenticated user.
/// Pure Dart (no Flutter or Dio dependencies).
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }
}

/// Overall auth state for the application.
class AuthState {
  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.errorMessage,
  });

  final UserProfile? user;
  final String? token;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    UserProfile? user,
    bool clearUser = false,
    String? token,
    bool clearToken = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
