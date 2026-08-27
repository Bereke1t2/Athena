import 'package:shared_preferences/shared_preferences.dart';

/// Local, device-only user preferences. Athena has no auth yet (Phase 5), so
/// the onboarding interests live here until accounts exist.
class UserPreferences {
  UserPreferences._();

  static final UserPreferences instance = UserPreferences._();

  static const _kOnboarded = 'athena.onboarding.complete';
  static const _kTopics = 'athena.onboarding.topics';

  SharedPreferences? _prefs;

  bool get _ready => _prefs != null;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  bool get onboarded => _ready && (_prefs!.getBool(_kOnboarded) ?? false);

  List<String> get topicSlugs =>
      _ready ? (_prefs!.getStringList(_kTopics) ?? const <String>[]) : const <String>[];

  /// Persists onboarding completion; keeps at most [maxTopics] slugs.
  Future<void> completeOnboarding(List<String> slugs) async {
    await load();
    await _prefs!.setStringList(_kTopics, slugs.take(maxTopics).toList());
    await _prefs!.setBool(_kOnboarded, true);
  }

  Future<void> reset() async {
    if (!_ready) return;
    await _prefs!.remove(_kTopics);
    await _prefs!.remove(_kOnboarded);
  }

  static const maxTopics = 12;
}
