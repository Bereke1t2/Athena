import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local user preferences and secure session state.
class UserPreferences {
  UserPreferences._();

  static final UserPreferences instance = UserPreferences._();

  static const _kOnboarded = 'athena.onboarding.complete';
  static const _kTopics = 'athena.onboarding.topics';
  static const _kLegacyAuthToken = 'athena.auth.token';
  static const _kSecureAuthToken = 'athena.auth.secure_token';
  static const _kUserId = 'athena.auth.user_id';
  static const _kUserEmail = 'athena.auth.user_email';
  static const _kUserDisplayName = 'athena.auth.user_display_name';

  SharedPreferences? _prefs;
  FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _cachedAuthToken;

  @visibleForTesting
  void setSecureStorageForTest(FlutterSecureStorage storage) {
    _secureStorage = storage;
  }

  bool get _ready => _prefs != null;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      _cachedAuthToken = await _secureStorage.read(key: _kSecureAuthToken);
    } catch (_) {
      // Graceful fallback in non-platform test environments
    }

    // Migration: check if legacy token is in SharedPreferences
    if (_cachedAuthToken == null && _prefs != null) {
      final legacyToken = _prefs!.getString(_kLegacyAuthToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        _cachedAuthToken = legacyToken;
        try {
          await _secureStorage.write(key: _kSecureAuthToken, value: legacyToken);
        } catch (_) {}
        await _prefs!.remove(_kLegacyAuthToken);
      }
    }
  }

  bool get onboarded => _ready && (_prefs!.getBool(_kOnboarded) ?? false);

  List<String> get topicSlugs =>
      _ready ? (_prefs!.getStringList(_kTopics) ?? const <String>[]) : const <String>[];

  String? get authToken => _cachedAuthToken;
  String? get userId => _ready ? _prefs!.getString(_kUserId) : null;
  String? get userEmail => _ready ? _prefs!.getString(_kUserEmail) : null;
  String? get userDisplayName => _ready ? _prefs!.getString(_kUserDisplayName) : null;

  /// Persists onboarding completion; keeps at most [maxTopics] slugs.
  Future<void> completeOnboarding(List<String> slugs) async {
    await load();
    await _prefs!.setStringList(_kTopics, slugs.take(maxTopics).toList());
    await _prefs!.setBool(_kOnboarded, true);
  }

  Future<void> saveAuthSession({
    required String token,
    required String id,
    required String email,
    required String displayName,
  }) async {
    await load();
    _cachedAuthToken = token;
    try {
      await _secureStorage.write(key: _kSecureAuthToken, value: token);
    } catch (_) {}
    if (_prefs != null) {
      await _prefs!.remove(_kLegacyAuthToken);
      await _prefs!.setString(_kUserId, id);
      await _prefs!.setString(_kUserEmail, email);
      await _prefs!.setString(_kUserDisplayName, displayName);
    }
  }

  Future<void> clearAuthSession() async {
    _cachedAuthToken = null;
    try {
      await _secureStorage.delete(key: _kSecureAuthToken);
    } catch (_) {}
    if (!_ready) return;
    await _prefs!.remove(_kLegacyAuthToken);
    await _prefs!.remove(_kUserId);
    await _prefs!.remove(_kUserEmail);
    await _prefs!.remove(_kUserDisplayName);
  }

  Future<void> reset() async {
    if (!_ready) return;
    await _prefs!.remove(_kTopics);
    await _prefs!.remove(_kOnboarded);
    await clearAuthSession();
  }

  static const maxTopics = 12;
}
