// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_papers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$savedPapersHash() => r'dff098335102629c73ddf15f68070d0af0533efa';

/// Local reading list, newest-saved first. [prime] must run in main() before
/// the first widget build so the synchronous provider starts populated.
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
