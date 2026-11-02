import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/error/failure.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../follows/presentation/follows_notifier.dart';
import '../domain/digest_models.dart';
import '../domain/digest_repository.dart';

class DigestState {
  const DigestState({
    this.isLoading = false,
    this.isGenerating = false,
    this.digest,
    this.error,
  });

  final bool isLoading;
  final bool isGenerating;
  final UserDigest? digest;
  final Object? error;

  DigestState copyWith({
    bool? isLoading,
    bool? isGenerating,
    UserDigest? digest,
    Object? error,
  }) {
    return DigestState(
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      digest: digest ?? this.digest,
      error: error,
    );
  }
}

class DigestNotifier extends StateNotifier<DigestState> {
  DigestNotifier(
    this._repo, {
    this.isAuthenticated = false,
    List<String> followedTopics = const [],
  })  : _followedTopics = followedTopics,
        super(const DigestState()) {
    loadLatest();
  }

  final DigestRepository _repo;
  final bool isAuthenticated;
  final List<String> _followedTopics;

  List<String> get followedTopics => List.unmodifiable(_followedTopics);

  Future<void> loadLatest({List<String>? topics}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activeTopics = topics ?? _followedTopics;
      final d = await _repo.getLatestDigest(topics: activeTopics.isNotEmpty ? activeTopics : null);
      state = state.copyWith(isLoading: false, digest: d, error: null);
    } catch (e) {
      final failure = e is Failure ? e : Failure.unknown(cause: e);
      state = state.copyWith(isLoading: false, error: failure);
    }
  }

  Future<void> regenerate({String frequency = 'weekly', List<String>? topics}) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final activeTopics = topics ?? _followedTopics;
      final d = await _repo.generateDigest(frequency: frequency, topics: activeTopics.isNotEmpty ? activeTopics : null);
      state = state.copyWith(isGenerating: false, digest: d, error: null);
    } catch (e) {
      final failure = e is Failure ? e : Failure.unknown(cause: e);
      state = state.copyWith(isGenerating: false, error: failure);
    }
  }
}

final digestNotifierProvider =
    StateNotifierProvider<DigestNotifier, DigestState>((ref) {
  final repo = ref.watch(digestRepositoryProvider);
  final auth = ref.watch(authNotifierProvider);
  final follows = ref.watch(followsNotifierProvider);
  final topicSlugs = follows.followedTopics.map((t) => t.topicSlug).toList();
  return DigestNotifier(
    repo,
    isAuthenticated: auth.isAuthenticated,
    followedTopics: topicSlugs,
  );
});
