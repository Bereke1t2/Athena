import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../domain/paper.dart';
import '../domain/paper_repository.dart';

class AuthorDetailState {
  const AuthorDetailState({
    this.author,
    this.works = const [],
    this.totalWorks = 0,
    this.isLoading = false,
    this.isLoadingWorks = false,
    this.error,
    this.sort = 'citations',
  });

  final AuthorDetail? author;
  final List<PaperSummary> works;
  final int totalWorks;
  final bool isLoading;
  final bool isLoadingWorks;
  final String? error;
  final String sort;

  AuthorDetailState copyWith({
    AuthorDetail? author,
    List<PaperSummary>? works,
    int? totalWorks,
    bool? isLoading,
    bool? isLoadingWorks,
    String? error,
    bool clearError = false,
    String? sort,
  }) {
    return AuthorDetailState(
      author: author ?? this.author,
      works: works ?? this.works,
      totalWorks: totalWorks ?? this.totalWorks,
      isLoading: isLoading ?? this.isLoading,
      isLoadingWorks: isLoadingWorks ?? this.isLoadingWorks,
      error: clearError ? null : (error ?? this.error),
      sort: sort ?? this.sort,
    );
  }
}

class AuthorDetailNotifier extends StateNotifier<AuthorDetailState> {
  AuthorDetailNotifier(this._repo, this.authorId, {String? initialName})
      : super(AuthorDetailState(
          author: initialName != null && initialName.isNotEmpty
              ? AuthorDetail(
                  id: authorId,
                  displayName: initialName,
                  nameNormalized: initialName.toLowerCase(),
                )
              : null,
          isLoading: true,
        )) {
    load();
  }

  final PaperRepository _repo;
  final String authorId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.getAuthorById(authorId),
        _repo.getAuthorPapers(authorId, sort: state.sort),
      ]);

      final author = results[0] as AuthorDetail;
      final works = results[1] as AuthorWorks;

      state = state.copyWith(
        author: author,
        works: works.items,
        totalWorks: works.total,
        isLoading: false,
      );
    } catch (e) {
      // Fallback: if single-author lookup fails, try loading works catalog
      try {
        final works = await _repo.getAuthorPapers(authorId, sort: state.sort);
        state = state.copyWith(
          works: works.items,
          totalWorks: works.total,
          isLoading: false,
        );
      } catch (_) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    }
  }

  Future<void> setSort(String newSort) async {
    if (state.sort == newSort) return;
    state = state.copyWith(sort: newSort, isLoadingWorks: true);
    try {
      final works = await _repo.getAuthorPapers(authorId, sort: newSort);
      state = state.copyWith(
        works: works.items,
        totalWorks: works.total,
        isLoadingWorks: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingWorks: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refresh() async => load();
}

final authorDetailProvider = StateNotifierProvider.family<
    AuthorDetailNotifier,
    AuthorDetailState,
    String>((ref, authorId) {
  final repo = ref.watch(paperRepositoryProvider);
  return AuthorDetailNotifier(repo, authorId);
});
