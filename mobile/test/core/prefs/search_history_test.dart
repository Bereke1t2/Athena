import 'package:athena/core/prefs/prefs_providers.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load(force: true);
  });

  test('UserPreferences searchHistory is initially empty', () {
    expect(UserPreferences.instance.searchHistory, isEmpty);
  });

  test('UserPreferences records search queries and deduplicates case-insensitively', () async {
    await UserPreferences.instance.addSearchHistory('machine learning');
    expect(UserPreferences.instance.searchHistory, equals(['machine learning']));

    await UserPreferences.instance.addSearchHistory('quantum computing');
    expect(UserPreferences.instance.searchHistory, equals(['quantum computing', 'machine learning']));

    // Re-adding same query brings it to the front
    await UserPreferences.instance.addSearchHistory('Machine Learning');
    expect(UserPreferences.instance.searchHistory, equals(['Machine Learning', 'quantum computing']));
  });

  test('UserPreferences limits search history to maximum 10 items', () async {
    for (var i = 1; i <= 15; i++) {
      await UserPreferences.instance.addSearchHistory('Query $i');
    }
    expect(UserPreferences.instance.searchHistory.length, equals(10));
    expect(UserPreferences.instance.searchHistory.first, equals('Query 15'));
    expect(UserPreferences.instance.searchHistory.last, equals('Query 6'));
  });

  test('UserPreferences removes specific query and clears all', () async {
    await UserPreferences.instance.addSearchHistory('Alpha');
    await UserPreferences.instance.addSearchHistory('Beta');
    expect(UserPreferences.instance.searchHistory.length, equals(2));

    await UserPreferences.instance.removeSearchHistory('alpha');
    expect(UserPreferences.instance.searchHistory, equals(['Beta']));

    await UserPreferences.instance.clearSearchHistory();
    expect(UserPreferences.instance.searchHistory, isEmpty);
  });

  test('searchHistoryProvider reflects UserPreferences and notifies state changes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(searchHistoryProvider), isEmpty);

    await container.read(searchHistoryProvider.notifier).add('Transformers');
    expect(container.read(searchHistoryProvider), equals(['Transformers']));

    await container.read(searchHistoryProvider.notifier).add('Diffusion');
    expect(container.read(searchHistoryProvider), equals(['Diffusion', 'Transformers']));

    await container.read(searchHistoryProvider.notifier).remove('Transformers');
    expect(container.read(searchHistoryProvider), equals(['Diffusion']));

    await container.read(searchHistoryProvider.notifier).clear();
    expect(container.read(searchHistoryProvider), isEmpty);
  });
}
