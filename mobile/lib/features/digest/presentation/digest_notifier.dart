import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
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
  DigestNotifier(this._repo) : super(const DigestState()) {
    loadLatest();
  }

  final DigestRepository _repo;

  Future<void> loadLatest() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final d = await _repo.getLatestDigest();
      state = state.copyWith(isLoading: false, digest: d);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> regenerate({String frequency = 'weekly'}) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final d = await _repo.generateDigest(frequency: frequency);
      state = state.copyWith(isGenerating: false, digest: d);
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e);
    }
  }
}

final digestNotifierProvider =
    StateNotifierProvider<DigestNotifier, DigestState>((ref) {
  return DigestNotifier(ref.watch(digestRepositoryProvider));
});
