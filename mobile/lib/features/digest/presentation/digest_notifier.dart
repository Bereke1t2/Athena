import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/error/failure.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../follows/presentation/follows_notifier.dart';
import '../../papers/domain/audio_playback.dart';
import '../domain/digest_models.dart';
import '../domain/digest_repository.dart';

class DigestState {
  const DigestState({
    this.isLoading = false,
    this.isGenerating = false,
    this.isSynthesizingAudio = false,
    this.digest,
    this.audioTrack,
    this.error,
    this.audioError,
  });

  final bool isLoading;
  final bool isGenerating;
  final bool isSynthesizingAudio;
  final UserDigest? digest;
  final AudioTrack? audioTrack;
  final Object? error;
  final Object? audioError;

  DigestState copyWith({
    bool? isLoading,
    bool? isGenerating,
    bool? isSynthesizingAudio,
    UserDigest? digest,
    AudioTrack? audioTrack,
    Object? error,
    Object? audioError,
  }) {
    return DigestState(
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      isSynthesizingAudio: isSynthesizingAudio ?? this.isSynthesizingAudio,
      digest: digest ?? this.digest,
      audioTrack: audioTrack ?? this.audioTrack,
      error: error,
      audioError: audioError,
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

  Future<AudioTrack?> synthesizeAudio({String? voice, List<String>? topics}) async {
    state = state.copyWith(isSynthesizingAudio: true, audioError: null);
    try {
      final activeTopics = topics ?? _followedTopics;
      final track = await _repo.synthesizeDigestAudio(
        voice: voice,
        topics: activeTopics.isNotEmpty ? activeTopics : null,
      );
      state = state.copyWith(
        isSynthesizingAudio: false,
        audioTrack: track,
        audioError: null,
      );
      return track;
    } catch (e) {
      final failure = e is Failure ? e : Failure.unknown(cause: e);
      state = state.copyWith(isSynthesizingAudio: false, audioError: failure);
      return null;
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
