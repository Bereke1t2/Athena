import 'package:athena/core/prefs/prefs_providers.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load();
  });

  test('appThemeModeProvider defaults to ThemeMode.dark (black) by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mode = container.read(appThemeModeProvider);
    expect(mode, equals(ThemeMode.dark));
    expect(UserPreferences.instance.themeMode, equals('dark'));
  });

  test('toggle switches between ThemeMode.dark and ThemeMode.light and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state is dark
    expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));

    // Toggle to light
    container.read(appThemeModeProvider.notifier).toggle();
    expect(container.read(appThemeModeProvider), equals(ThemeMode.light));
    expect(UserPreferences.instance.themeMode, equals('light'));

    // Toggle back to dark
    container.read(appThemeModeProvider.notifier).toggle();
    expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));
    expect(UserPreferences.instance.themeMode, equals('dark'));
  });

  test('setMode explicitly sets theme and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appThemeModeProvider.notifier).setMode(ThemeMode.light);
    expect(container.read(appThemeModeProvider), equals(ThemeMode.light));
    expect(UserPreferences.instance.themeMode, equals('light'));

    container.read(appThemeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));
    expect(UserPreferences.instance.themeMode, equals('dark'));
  });
}
