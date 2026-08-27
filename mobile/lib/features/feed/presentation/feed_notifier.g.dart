// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$feedNotifierHash() => r'73ba15ea7f9e70856fbe24d65d6c7822b4236fd9';

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

abstract class _$FeedNotifier
    extends BuildlessAutoDisposeAsyncNotifier<FeedPageState> {
  late final FeedSection section;

  FutureOr<FeedPageState> build(
    FeedSection section,
  );
}

/// Feed for one section, filtered to the user's onboarding interests. Watches
/// [selectedTopicsProvider], so saving new topics refreshes automatically.
///
/// Copied from [FeedNotifier].
@ProviderFor(FeedNotifier)
const feedNotifierProvider = FeedNotifierFamily();

/// Feed for one section, filtered to the user's onboarding interests. Watches
/// [selectedTopicsProvider], so saving new topics refreshes automatically.
///
/// Copied from [FeedNotifier].
class FeedNotifierFamily extends Family<AsyncValue<FeedPageState>> {
  /// Feed for one section, filtered to the user's onboarding interests. Watches
  /// [selectedTopicsProvider], so saving new topics refreshes automatically.
  ///
  /// Copied from [FeedNotifier].
  const FeedNotifierFamily();

  /// Feed for one section, filtered to the user's onboarding interests. Watches
  /// [selectedTopicsProvider], so saving new topics refreshes automatically.
  ///
  /// Copied from [FeedNotifier].
  FeedNotifierProvider call(
    FeedSection section,
  ) {
    return FeedNotifierProvider(
      section,
    );
  }

  @override
  FeedNotifierProvider getProviderOverride(
    covariant FeedNotifierProvider provider,
  ) {
    return call(
      provider.section,
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
  String? get name => r'feedNotifierProvider';
}

/// Feed for one section, filtered to the user's onboarding interests. Watches
/// [selectedTopicsProvider], so saving new topics refreshes automatically.
///
/// Copied from [FeedNotifier].
class FeedNotifierProvider
    extends AutoDisposeAsyncNotifierProviderImpl<FeedNotifier, FeedPageState> {
  /// Feed for one section, filtered to the user's onboarding interests. Watches
  /// [selectedTopicsProvider], so saving new topics refreshes automatically.
  ///
  /// Copied from [FeedNotifier].
  FeedNotifierProvider(
    FeedSection section,
  ) : this._internal(
          () => FeedNotifier()..section = section,
          from: feedNotifierProvider,
          name: r'feedNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$feedNotifierHash,
          dependencies: FeedNotifierFamily._dependencies,
          allTransitiveDependencies:
              FeedNotifierFamily._allTransitiveDependencies,
          section: section,
        );

  FeedNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.section,
  }) : super.internal();

  final FeedSection section;

  @override
  FutureOr<FeedPageState> runNotifierBuild(
    covariant FeedNotifier notifier,
  ) {
    return notifier.build(
      section,
    );
  }

  @override
  Override overrideWith(FeedNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: FeedNotifierProvider._internal(
        () => create()..section = section,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        section: section,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<FeedNotifier, FeedPageState>
      createElement() {
    return _FeedNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is FeedNotifierProvider && other.section == section;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, section.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin FeedNotifierRef on AutoDisposeAsyncNotifierProviderRef<FeedPageState> {
  /// The parameter `section` of this provider.
  FeedSection get section;
}

class _FeedNotifierProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<FeedNotifier, FeedPageState>
    with FeedNotifierRef {
  _FeedNotifierProviderElement(super.provider);

  @override
  FeedSection get section => (origin as FeedNotifierProvider).section;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
