// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topics_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$topicListNotifierHash() => r'3f58774ae76af4c97a20765564c437aa7fe50d30';

/// See also [TopicListNotifier].
@ProviderFor(TopicListNotifier)
final topicListNotifierProvider = AutoDisposeAsyncNotifierProvider<
    TopicListNotifier, TopicListState>.internal(
  TopicListNotifier.new,
  name: r'topicListNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$topicListNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$TopicListNotifier = AutoDisposeAsyncNotifier<TopicListState>;
String _$topicDetailControllerHash() =>
    r'f7ab83d3e21e6e755ccbf43b3c086f451cd97129';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$TopicDetailController
    extends BuildlessAutoDisposeAsyncNotifier<Topic> {
  late final String slug;

  FutureOr<Topic> build(
    String slug,
  );
}

/// See also [TopicDetailController].
@ProviderFor(TopicDetailController)
const topicDetailControllerProvider = TopicDetailControllerFamily();

/// See also [TopicDetailController].
class TopicDetailControllerFamily extends Family<AsyncValue<Topic>> {
  /// See also [TopicDetailController].
  const TopicDetailControllerFamily();

  /// See also [TopicDetailController].
  TopicDetailControllerProvider call(
    String slug,
  ) {
    return TopicDetailControllerProvider(
      slug,
    );
  }

  @override
  TopicDetailControllerProvider getProviderOverride(
    covariant TopicDetailControllerProvider provider,
  ) {
    return call(
      provider.slug,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'topicDetailControllerProvider';
}

/// See also [TopicDetailController].
class TopicDetailControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<TopicDetailController, Topic> {
  /// See also [TopicDetailController].
  TopicDetailControllerProvider(
    String slug,
  ) : this._internal(
          () => TopicDetailController()..slug = slug,
          from: topicDetailControllerProvider,
          name: r'topicDetailControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$topicDetailControllerHash,
          dependencies: TopicDetailControllerFamily._dependencies,
          allTransitiveDependencies:
              TopicDetailControllerFamily._allTransitiveDependencies,
          slug: slug,
        );

  TopicDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
  }) : super.internal();

  final String slug;

  @override
  FutureOr<Topic> runNotifierBuild(
    covariant TopicDetailController notifier,
  ) {
    return notifier.build(
      slug,
    );
  }

  @override
  Override overrideWith(TopicDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: TopicDetailControllerProvider._internal(
        () => create()..slug = slug,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<TopicDetailController, Topic>
      createElement() {
    return _TopicDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TopicDetailControllerProvider && other.slug == slug;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TopicDetailControllerRef on AutoDisposeAsyncNotifierProviderRef<Topic> {
  /// The parameter `slug` of this provider.
  String get slug;
}

class _TopicDetailControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TopicDetailController,
        Topic> with TopicDetailControllerRef {
  _TopicDetailControllerProviderElement(super.provider);

  @override
  String get slug => (origin as TopicDetailControllerProvider).slug;
}

String _$topicPapersNotifierHash() =>
    r'b9c8afe031e0e461c7a210c62ca9d5df780cf604';

abstract class _$TopicPapersNotifier
    extends BuildlessAutoDisposeAsyncNotifier<PaperListPage> {
  late final String slug;
  late final String sort;

  FutureOr<PaperListPage> build(
    String slug, {
    String sort = 'relevance',
  });
}

/// Papers filed under one topic (topic detail screen's list).
///
/// Copied from [TopicPapersNotifier].
@ProviderFor(TopicPapersNotifier)
const topicPapersNotifierProvider = TopicPapersNotifierFamily();

/// Papers filed under one topic (topic detail screen's list).
///
/// Copied from [TopicPapersNotifier].
class TopicPapersNotifierFamily extends Family<AsyncValue<PaperListPage>> {
  /// Papers filed under one topic (topic detail screen's list).
  ///
  /// Copied from [TopicPapersNotifier].
  const TopicPapersNotifierFamily();

  /// Papers filed under one topic (topic detail screen's list).
  ///
  /// Copied from [TopicPapersNotifier].
  TopicPapersNotifierProvider call(
    String slug, {
    String sort = 'relevance',
  }) {
    return TopicPapersNotifierProvider(
      slug,
      sort: sort,
    );
  }

  @override
  TopicPapersNotifierProvider getProviderOverride(
    covariant TopicPapersNotifierProvider provider,
  ) {
    return call(
      provider.slug,
      sort: provider.sort,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'topicPapersNotifierProvider';
}

/// Papers filed under one topic (topic detail screen's list).
///
/// Copied from [TopicPapersNotifier].
class TopicPapersNotifierProvider extends AutoDisposeAsyncNotifierProviderImpl<
    TopicPapersNotifier, PaperListPage> {
  /// Papers filed under one topic (topic detail screen's list).
  ///
  /// Copied from [TopicPapersNotifier].
  TopicPapersNotifierProvider(
    String slug, {
    String sort = 'relevance',
  }) : this._internal(
          () => TopicPapersNotifier()
            ..slug = slug
            ..sort = sort,
          from: topicPapersNotifierProvider,
          name: r'topicPapersNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$topicPapersNotifierHash,
          dependencies: TopicPapersNotifierFamily._dependencies,
          allTransitiveDependencies:
              TopicPapersNotifierFamily._allTransitiveDependencies,
          slug: slug,
          sort: sort,
        );

  TopicPapersNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.slug,
    required this.sort,
  }) : super.internal();

  final String slug;
  final String sort;

  @override
  FutureOr<PaperListPage> runNotifierBuild(
    covariant TopicPapersNotifier notifier,
  ) {
    return notifier.build(
      slug,
      sort: sort,
    );
  }

  @override
  Override overrideWith(TopicPapersNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: TopicPapersNotifierProvider._internal(
        () => create()
          ..slug = slug
          ..sort = sort,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        slug: slug,
        sort: sort,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<TopicPapersNotifier, PaperListPage>
      createElement() {
    return _TopicPapersNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is TopicPapersNotifierProvider &&
        other.slug == slug &&
        other.sort == sort;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, slug.hashCode);
    hash = _SystemHash.combine(hash, sort.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin TopicPapersNotifierRef
    on AutoDisposeAsyncNotifierProviderRef<PaperListPage> {
  /// The parameter `slug` of this provider.
  String get slug;

  /// The parameter `sort` of this provider.
  String get sort;
}

class _TopicPapersNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<TopicPapersNotifier,
        PaperListPage> with TopicPapersNotifierRef {
  _TopicPapersNotifierProviderElement(super.provider);

  @override
  String get slug => (origin as TopicPapersNotifierProvider).slug;
  @override
  String get sort => (origin as TopicPapersNotifierProvider).sort;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
