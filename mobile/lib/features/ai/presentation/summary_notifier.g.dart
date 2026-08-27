// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$summaryNotifierHash() => r'da03db61b04576d30484092d17e37899fde341ea';

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

abstract class _$SummaryNotifier
    extends BuildlessAutoDisposeNotifier<SummaryState> {
  late final String paperId;

  SummaryState build(
    String paperId,
  );
}

/// One summary per paper; switching levels re-fetches (server cache makes
/// repeat levels free).
///
/// Copied from [SummaryNotifier].
@ProviderFor(SummaryNotifier)
const summaryNotifierProvider = SummaryNotifierFamily();

/// One summary per paper; switching levels re-fetches (server cache makes
/// repeat levels free).
///
/// Copied from [SummaryNotifier].
class SummaryNotifierFamily extends Family<SummaryState> {
  /// One summary per paper; switching levels re-fetches (server cache makes
  /// repeat levels free).
  ///
  /// Copied from [SummaryNotifier].
  const SummaryNotifierFamily();

  /// One summary per paper; switching levels re-fetches (server cache makes
  /// repeat levels free).
  ///
  /// Copied from [SummaryNotifier].
  SummaryNotifierProvider call(
    String paperId,
  ) {
    return SummaryNotifierProvider(
      paperId,
    );
  }

  @override
  SummaryNotifierProvider getProviderOverride(
    covariant SummaryNotifierProvider provider,
  ) {
    return call(
      provider.paperId,
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
  String? get name => r'summaryNotifierProvider';
}

/// One summary per paper; switching levels re-fetches (server cache makes
/// repeat levels free).
///
/// Copied from [SummaryNotifier].
class SummaryNotifierProvider
    extends AutoDisposeNotifierProviderImpl<SummaryNotifier, SummaryState> {
  /// One summary per paper; switching levels re-fetches (server cache makes
  /// repeat levels free).
  ///
  /// Copied from [SummaryNotifier].
  SummaryNotifierProvider(
    String paperId,
  ) : this._internal(
          () => SummaryNotifier()..paperId = paperId,
          from: summaryNotifierProvider,
          name: r'summaryNotifierProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$summaryNotifierHash,
          dependencies: SummaryNotifierFamily._dependencies,
          allTransitiveDependencies:
              SummaryNotifierFamily._allTransitiveDependencies,
          paperId: paperId,
        );

  SummaryNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.paperId,
  }) : super.internal();

  final String paperId;

  @override
  SummaryState runNotifierBuild(
    covariant SummaryNotifier notifier,
  ) {
    return notifier.build(
      paperId,
    );
  }

  @override
  Override overrideWith(SummaryNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: SummaryNotifierProvider._internal(
        () => create()..paperId = paperId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        paperId: paperId,
      ),
    );
  }

  @override
  AutoDisposeNotifierProviderElement<SummaryNotifier, SummaryState>
      createElement() {
    return _SummaryNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SummaryNotifierProvider && other.paperId == paperId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, paperId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SummaryNotifierRef on AutoDisposeNotifierProviderRef<SummaryState> {
  /// The parameter `paperId` of this provider.
  String get paperId;
}

class _SummaryNotifierProviderElement
    extends AutoDisposeNotifierProviderElement<SummaryNotifier, SummaryState>
    with SummaryNotifierRef {
  _SummaryNotifierProviderElement(super.provider);

  @override
  String get paperId => (origin as SummaryNotifierProvider).paperId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
