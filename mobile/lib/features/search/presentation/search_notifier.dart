import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di.dart';
import '../../../core/error/failure.dart';
import '../domain/search.dart';

part 'search_notifier.freezed.dart';
part 'search_notifier.g.dart';

@freezed
sealed class SearchPageState with _$SearchPageState {
  const factory SearchPageState({
    required List<SearchResult> results,
    String? cursor,
    @Default('') String modeUsed,
    @Default(-1) int totalEstimate,
    @Default(false) bool loadingMore,
    @Default(<SearchSourceStatus>[]) List<SearchSourceStatus> sources,
    @Default(0) int tookMs,
  }) = _SearchPageState;
}

/// UI state: current filters + the async result page.
@freezed
sealed class SearchState with _$SearchState {
  const factory SearchState({
    @Default(SearchFilters(query: '')) SearchFilters filters,
    @Default(AsyncValue<SearchPageState>.loading()) AsyncValue<SearchPageState> page,
    @Default(false) bool submitted,
  }) = _SearchState;
}

@riverpod
class SearchNotifier extends _$SearchNotifier {
  bool _hasQuery = false;

  @override
  SearchState build() => const SearchState();

  /// Submits a new query (resets pagination and filters' query part).
  Future<void> submit(String rawQuery) async {
    final q = rawQuery.trim();
    if (q.isEmpty) return;
    _hasQuery = true;
    state = state.copyWith(
      filters: state.filters.copyWith(query: q),
      page: const AsyncValue.loading(),
      submitted: true,
    );
    await _run(cursor: null);
  }

  Future<void> setSort(SearchSort sort) async {
    if (!_hasQuery || sort == state.filters.sort) return;
    state = state.copyWith(
      filters: state.filters.copyWith(sort: sort),
      page: const AsyncValue.loading(),
    );
    await _run(cursor: null);
  }

  Future<void> setOpenAccessOnly(bool oaOnly) async {
    if (!_hasQuery) return;
    state = state.copyWith(
      filters: state.filters.copyWith(openAccess: oaOnly ? true : null),
      page: const AsyncValue.loading(),
    );
    await _run(cursor: null);
  }

  Future<void> loadMore() async {
    final pageState = state.page.valueOrNull;
    if (pageState == null ||
        pageState.loadingMore ||
        pageState.cursor == null ||
        !_hasQuery) {
      return;
    }
    state = state.copyWith(
      page: AsyncData(pageState.copyWith(loadingMore: true)),
    );
    await _run(cursor: pageState.cursor, appendTo: pageState);
  }

  Future<void> _run({required String? cursor, SearchPageState? appendTo}) async {
    try {
      final result = await ref.read(searchRepositoryProvider).search(
            state.filters,
            cursor: cursor,
            limit: Paging.defaultLimit,
          );
      final next = SearchPageState(
        results: appendTo == null
            ? result.items
            : [...appendTo.results, ...result.items],
        cursor: result.nextCursor,
        modeUsed: result.modeUsed,
        totalEstimate: result.totalEstimate,
        sources: result.sources,
        tookMs: result.tookMs,
      );
      state = state.copyWith(page: AsyncData(next));
    } on Failure catch (f, st) {
      if (appendTo != null) {
        // Pagination failure keeps prior content.
        state = state.copyWith(
          page: AsyncData(appendTo.copyWith(loadingMore: false)),
        );
      } else {
        state = state.copyWith(page: AsyncError(f, st));
      }
    }
  }
}
