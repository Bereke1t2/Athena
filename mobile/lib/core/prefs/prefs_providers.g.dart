// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prefs_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$selectedTopicsHash() => r'5d22e0663f18180688211389c1d6be43f32b7aa9';

/// The topic slugs the user picked during onboarding. Feed controllers watch
/// this, so saving new interests refreshes every feed section automatically.
///
/// Copied from [SelectedTopics].
@ProviderFor(SelectedTopics)
final selectedTopicsProvider =
    AutoDisposeNotifierProvider<SelectedTopics, List<String>>.internal(
  SelectedTopics.new,
  name: r'selectedTopicsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedTopicsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedTopics = AutoDisposeNotifier<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
