// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_papers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$savedPapersHash() => r'd0623335b0c53d03b6d205494020f4cd0cccc839';

/// Reading list, newest-saved first. [prime] runs in main() before the first
/// build. When authenticated, operations sync in the background with Athena's API.
///
/// Copied from [SavedPapers].
@ProviderFor(SavedPapers)
final savedPapersProvider =
    AutoDisposeNotifierProvider<SavedPapers, List<SavedPaper>>.internal(
  SavedPapers.new,
  name: r'savedPapersProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$savedPapersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SavedPapers = AutoDisposeNotifier<List<SavedPaper>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
