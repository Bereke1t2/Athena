import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../domain/history_repository.dart';
import '../domain/reading_history.dart';

class HistoryState {
  const HistoryState({
    this.isLoading = false,
    this.items = const [],
    this.nextCursor = '',
    this.error,
  });

  final bool isLoading;
  final List<HistoryEntry> items;
  final String nextCursor;
  final Object? error;

  bool get hasMore => nextCursor.isNotEmpty;

  HistoryState copyWith({
    bool? isLoading,
    List<HistoryEntry>? items,
    String? nextCursor,
    Object? error,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      nextCursor: nextCursor ?? this.nextCursor,
      error: error,
    );
  }
}

class HistoryNotifier extends StateNotifier<HistoryState> {
  HistoryNotifier(this._repo) : super(const HistoryState()) {
    loadInitial();
  }

  final HistoryRepository _repo;

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _repo.listHistory(limit: 20);
      state = state.copyWith(
        isLoading: false,
        items: res.items,
        nextCursor: res.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    try {
      final res = await _repo.listHistory(cursor: state.nextCursor, limit: 20);
      state = state.copyWith(
        items: [...state.items, ...res.items],
        nextCursor: res.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }

  Future<void> recordProgress(String paperId, double progressPercent) async {
    try {
      await _repo.recordProgress(
        paperId: paperId,
        progressPercent: progressPercent,
      );
    } catch (_) {
      // Background non-fatal sync
    }
  }

  Future<void> clearHistory() async {
    try {
      await _repo.clearHistory();
      state = state.copyWith(items: const [], nextCursor: '');
    } catch (e) {
      state = state.copyWith(error: e);
    }
  }
}

final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier(ref.watch(historyRepositoryProvider));
});
