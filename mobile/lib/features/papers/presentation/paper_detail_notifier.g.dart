// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paper_detail_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$paperDetailControllerHash() =>
    r'13ca6c508263433a0045c3b98d79503310f04c7a';

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
