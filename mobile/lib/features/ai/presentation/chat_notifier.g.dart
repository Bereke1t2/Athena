// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatThreadHash() => r'ccf76ccd7356d2338b1a039723c58181fffc8113';

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

abstract class _$ChatThread
    extends BuildlessAutoDisposeNotifier<ChatThreadState> {
  late final String paperId;

  ChatThreadState build(
    String paperId,
  );
}

/// One chat thread per paper. The session is created lazily on first send.
/// [keepAlive] preserves the transcript while navigating between screens.
///
/// Copied from [ChatThread].
@ProviderFor(ChatThread)
const chatThreadProvider = ChatThreadFamily();

/// One chat thread per paper. The session is created lazily on first send.
/// [keepAlive] preserves the transcript while navigating between screens.
///
/// Copied from [ChatThread].
class ChatThreadFamily extends Family<ChatThreadState> {
  /// One chat thread per paper. The session is created lazily on first send.
  /// [keepAlive] preserves the transcript while navigating between screens.
  ///
  /// Copied from [ChatThread].
  const ChatThreadFamily();

  /// One chat thread per paper. The session is created lazily on first send.
  /// [keepAlive] preserves the transcript while navigating between screens.
  ///
  /// Copied from [ChatThread].
  ChatThreadProvider call(
    String paperId,
  ) {
    return ChatThreadProvider(
      paperId,
    );
  }

  @override
  ChatThreadProvider getProviderOverride(
    covariant ChatThreadProvider provider,
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
  String? get name => r'chatThreadProvider';
}

/// One chat thread per paper. The session is created lazily on first send.
/// [keepAlive] preserves the transcript while navigating between screens.
///
/// Copied from [ChatThread].
class ChatThreadProvider
    extends AutoDisposeNotifierProviderImpl<ChatThread, ChatThreadState> {
  /// One chat thread per paper. The session is created lazily on first send.
  /// [keepAlive] preserves the transcript while navigating between screens.
  ///
  /// Copied from [ChatThread].
  ChatThreadProvider(
    String paperId,
  ) : this._internal(
          () => ChatThread()..paperId = paperId,
          from: chatThreadProvider,
          name: r'chatThreadProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$chatThreadHash,
          dependencies: ChatThreadFamily._dependencies,
          allTransitiveDependencies:
              ChatThreadFamily._allTransitiveDependencies,
          paperId: paperId,
        );

  ChatThreadProvider._internal(
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
  ChatThreadState runNotifierBuild(
    covariant ChatThread notifier,
  ) {
    return notifier.build(
      paperId,
    );
  }

  @override
  Override overrideWith(ChatThread Function() create) {
    return ProviderOverride(
      origin: this,
      override: ChatThreadProvider._internal(
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
  AutoDisposeNotifierProviderElement<ChatThread, ChatThreadState>
      createElement() {
    return _ChatThreadProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ChatThreadProvider && other.paperId == paperId;
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
mixin ChatThreadRef on AutoDisposeNotifierProviderRef<ChatThreadState> {
  /// The parameter `paperId` of this provider.
  String get paperId;
}

class _ChatThreadProviderElement
    extends AutoDisposeNotifierProviderElement<ChatThread, ChatThreadState>
    with ChatThreadRef {
  _ChatThreadProviderElement(super.provider);

  @override
  String get paperId => (origin as ChatThreadProvider).paperId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
