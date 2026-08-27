import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'user_preferences.dart';

part 'prefs_providers.g.dart';

/// The topic slugs the user picked during onboarding. Feed controllers watch
/// this, so saving new interests refreshes every feed section automatically.
@riverpod
class SelectedTopics extends _$SelectedTopics {
  @override
  List<String> build() => UserPreferences.instance.topicSlugs;

  void replace(List<String> slugs) {
    final capped = slugs.take(UserPreferences.maxTopics).toList();
    // Fire-and-forget: the in-memory state drives the UI immediately.
    UserPreferences.instance.completeOnboarding(capped);
    state = List.unmodifiable(capped);
  }
}

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(AppThemeModeNotifier.new);

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void toggle() {
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  void setMode(ThemeMode mode) {
    state = mode;
  }
}
