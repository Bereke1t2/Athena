import 'package:shared_preferences/shared_preferences.dart';

/// Local, device-only user preferences and cached session state.
class UserPreferences {
  UserPreferences._();

  static final UserPreferences instance = UserPreferences._();

  static const _kOnboarded = 'athena.onboarding.complete';
  static const _kTopics = 'athena.onboarding.topics';
  static const _kAuthToken = 'athena.auth.token';
  static const _kUserId = 'athena.auth.user_id';
  static const _kUserEmail = 'athena.auth.user_email';
  static const _kUserDisplayName = 'athena.auth.user_display_name';

  SharedPreferences? _prefs;

  bool get _ready => _prefs != null;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool get onboarded => _ready && (_prefs!.getBool(_kOnboarded) ?? false);

  List<String> get topicSlugs =>
      _ready ? (_prefs!.getStringList(_kTopics) ?? const <String>[]) : const <String>[];

  String? get authToken => _ready ? _prefs!.getString(_kAuthToken) : null;
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
    await _prefs!.setString(_kAuthToken, token);
    await _prefs!.setString(_kUserId, id);
    await _prefs!.setString(_kUserEmail, email);
    await _prefs!.setString(_kUserDisplayName, displayName);
  }

  Future<void> clearAuthSession() async {
    if (!_ready) return;
    await _prefs!.remove(_kAuthToken);
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
