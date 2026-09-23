// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paper_detail_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paperCitationsHash() => r'd196e4c50ced703f134380c774ea96f948256c1a';

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

/// See also [paperCitations].
@ProviderFor(paperCitations)
const paperCitationsProvider = PaperCitationsFamily();

/// See also [paperCitations].
class PaperCitationsFamily extends Family<AsyncValue<List<PaperSummary>>> {
  /// See also [paperCitations].
  const PaperCitationsFamily();

  /// See also [paperCitations].
  PaperCitationsProvider call(
    String id, {
    String direction = 'in',
  }) {
    return PaperCitationsProvider(
      id,
      direction: direction,
    );
  }

  @override
  PaperCitationsProvider getProviderOverride(
    covariant PaperCitationsProvider provider,
  ) {
    return call(
      provider.id,
      direction: provider.direction,
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
  String? get name => r'paperCitationsProvider';
}

/// See also [paperCitations].
class PaperCitationsProvider
    extends AutoDisposeFutureProvider<List<PaperSummary>> {
  /// See also [paperCitations].
  PaperCitationsProvider(
    String id, {
    String direction = 'in',
  }) : this._internal(
          (ref) => paperCitations(
            ref as PaperCitationsRef,
            id,
            direction: direction,
          ),
          from: paperCitationsProvider,
          name: r'paperCitationsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$paperCitationsHash,
          dependencies: PaperCitationsFamily._dependencies,
          allTransitiveDependencies:
              PaperCitationsFamily._allTransitiveDependencies,
          id: id,
          direction: direction,
        );

  PaperCitationsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
    required this.direction,
  }) : super.internal();

  final String id;
  final String direction;

  @override
  Override overrideWith(
    FutureOr<List<PaperSummary>> Function(PaperCitationsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PaperCitationsProvider._internal(
        (ref) => create(ref as PaperCitationsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
        direction: direction,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PaperSummary>> createElement() {
    return _PaperCitationsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PaperCitationsProvider &&
        other.id == id &&
        other.direction == direction;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);
    hash = _SystemHash.combine(hash, direction.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PaperCitationsRef on AutoDisposeFutureProviderRef<List<PaperSummary>> {
  /// The parameter `id` of this provider.
  String get id;

  /// The parameter `direction` of this provider.
  String get direction;
}

class _PaperCitationsProviderElement
    extends AutoDisposeFutureProviderElement<List<PaperSummary>>
    with PaperCitationsRef {
  _PaperCitationsProviderElement(super.provider);

  @override
  String get id => (origin as PaperCitationsProvider).id;
  @override
  String get direction => (origin as PaperCitationsProvider).direction;
}

String _$paperRelatedHash() => r'a8ca86b9f91b282a165ac9c61451800a37b58931';

/// See also [paperRelated].
@ProviderFor(paperRelated)
const paperRelatedProvider = PaperRelatedFamily();

/// See also [paperRelated].
class PaperRelatedFamily extends Family<AsyncValue<List<PaperSummary>>> {
  /// See also [paperRelated].
  const PaperRelatedFamily();

  /// See also [paperRelated].
  PaperRelatedProvider call(
    String id,
  ) {
    return PaperRelatedProvider(
      id,
    );
  }

  @override
  PaperRelatedProvider getProviderOverride(
    covariant PaperRelatedProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'paperRelatedProvider';
}

/// See also [paperRelated].
class PaperRelatedProvider
    extends AutoDisposeFutureProvider<List<PaperSummary>> {
  /// See also [paperRelated].
  PaperRelatedProvider(
    String id,
  ) : this._internal(
          (ref) => paperRelated(
            ref as PaperRelatedRef,
            id,
          ),
          from: paperRelatedProvider,
          name: r'paperRelatedProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$paperRelatedHash,
          dependencies: PaperRelatedFamily._dependencies,
          allTransitiveDependencies:
              PaperRelatedFamily._allTransitiveDependencies,
          id: id,
        );

  PaperRelatedProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<List<PaperSummary>> Function(PaperRelatedRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PaperRelatedProvider._internal(
        (ref) => create(ref as PaperRelatedRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<PaperSummary>> createElement() {
    return _PaperRelatedProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PaperRelatedProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PaperRelatedRef on AutoDisposeFutureProviderRef<List<PaperSummary>> {
  /// The parameter `id` of this provider.
  String get id;
}

class _PaperRelatedProviderElement
    extends AutoDisposeFutureProviderElement<List<PaperSummary>>
    with PaperRelatedRef {
  _PaperRelatedProviderElement(super.provider);

  @override
  String get id => (origin as PaperRelatedProvider).id;
}

String _$paperDetailControllerHash() =>
    r'13ca6c508263433a0045c3b98d79503310f04c7a';

abstract class _$PaperDetailController
    extends BuildlessAutoDisposeAsyncNotifier<PaperDetail> {
  late final String id;

  FutureOr<PaperDetail> build(
    String id,
  );
}

/// See also [PaperDetailController].
@ProviderFor(PaperDetailController)
const paperDetailControllerProvider = PaperDetailControllerFamily();

/// See also [PaperDetailController].
class PaperDetailControllerFamily extends Family<AsyncValue<PaperDetail>> {
  /// See also [PaperDetailController].
  const PaperDetailControllerFamily();

  /// See also [PaperDetailController].
  PaperDetailControllerProvider call(
    String id,
  ) {
    return PaperDetailControllerProvider(
      id,
    );
  }

  @override
  PaperDetailControllerProvider getProviderOverride(
    covariant PaperDetailControllerProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'paperDetailControllerProvider';
}

/// See also [PaperDetailController].
class PaperDetailControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<PaperDetailController,
        PaperDetail> {
  /// See also [PaperDetailController].
  PaperDetailControllerProvider(
    String id,
  ) : this._internal(
          () => PaperDetailController()..id = id,
          from: paperDetailControllerProvider,
          name: r'paperDetailControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$paperDetailControllerHash,
          dependencies: PaperDetailControllerFamily._dependencies,
          allTransitiveDependencies:
              PaperDetailControllerFamily._allTransitiveDependencies,
          id: id,
        );

  PaperDetailControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  FutureOr<PaperDetail> runNotifierBuild(
    covariant PaperDetailController notifier,
  ) {
    return notifier.build(
      id,
    );
  }

  @override
  Override overrideWith(PaperDetailController Function() create) {
    return ProviderOverride(
      origin: this,
      override: PaperDetailControllerProvider._internal(
        () => create()..id = id,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<PaperDetailController, PaperDetail>
      createElement() {
    return _PaperDetailControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PaperDetailControllerProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PaperDetailControllerRef
    on AutoDisposeAsyncNotifierProviderRef<PaperDetail> {
  /// The parameter `id` of this provider.
  String get id;
}

class _PaperDetailControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<PaperDetailController,
        PaperDetail> with PaperDetailControllerRef {
  _PaperDetailControllerProviderElement(super.provider);

  @override
  String get id => (origin as PaperDetailControllerProvider).id;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
