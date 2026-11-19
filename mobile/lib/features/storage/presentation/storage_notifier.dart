import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../papers/domain/pdf_repository.dart';
import '../domain/storage_models.dart';
import '../domain/storage_repository.dart';

class StorageState {
  const StorageState({
    required this.breakdown,
    required this.cachedPdfs,
    this.isLoading = false,
    this.batchDownloadProgress,
    this.message,
    this.error,
  });

  final StorageBreakdown breakdown;
  final List<CachedPdfInfo> cachedPdfs;
  final bool isLoading;
  final (int completed, int total)? batchDownloadProgress;
  final String? message;
  final String? error;

  StorageState copyWith({
    StorageBreakdown? breakdown,
    List<CachedPdfInfo>? cachedPdfs,
    bool? isLoading,
    (int completed, int total)? batchDownloadProgress,
    bool clearBatchProgress = false,
    String? message,
    String? error,
  }) {
    return StorageState(
      breakdown: breakdown ?? this.breakdown,
      cachedPdfs: cachedPdfs ?? this.cachedPdfs,
      isLoading: isLoading ?? this.isLoading,
      batchDownloadProgress:
          clearBatchProgress ? null : (batchDownloadProgress ?? this.batchDownloadProgress),
      message: message,
      error: error,
    );
  }
}

class StorageNotifier extends StateNotifier<StorageState> {
  StorageNotifier(this._repo)
      : super(const StorageState(
          breakdown: StorageBreakdown(
            pdfBytes: 0,
            pdfCount: 0,
            searchHistoryCount: 0,
            annotationsCount: 0,
          ),
          cachedPdfs: [],
          isLoading: true,
        )) {
    load();
  }

  final StorageRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final breakdown = await _repo.getStorageBreakdown();
      final cached = await _repo.listCachedPdfs();
      state = state.copyWith(
        breakdown: breakdown,
        cachedPdfs: cached,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deletePdf(String paperId) async {
    try {
      await _repo.deletePdf(paperId);
      await load();
      state = state.copyWith(message: 'Removed PDF from device storage');
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete PDF: $e');
    }
  }

  Future<void> clearAllPdfs() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.clearAllPdfs();
      await load();
      state = state.copyWith(message: 'Cleared all cached research PDFs');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to clear PDFs: $e');
    }
  }

  Future<void> clearSearchHistory() async {
    try {
      await _repo.clearSearchHistory();
      await load();
      state = state.copyWith(message: 'Cleared search history cache');
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear search history: $e');
    }
  }

  Future<void> clearAllStorage() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.clearAllStorage();
      await load();
      state = state.copyWith(message: 'Reset all local storage and cached files');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to reset storage: $e');
    }
  }

  Future<OfflineFlightBatchResult> downloadFlightPack(
    List<(String paperId, String pdfUrl)> items,
  ) async {
    state = state.copyWith(
      isLoading: true,
      batchDownloadProgress: (0, items.length),
    );

    try {
      final result = await _repo.downloadFlightPack(
        items,
        onProgress: (completed, total) {
          state = state.copyWith(batchDownloadProgress: (completed, total));
        },
      );

      await load();
      state = state.copyWith(
        clearBatchProgress: true,
        message: 'Flight Pack Ready: ${result.downloaded} downloaded, ${result.skipped} ready, ${result.failed} failed',
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        clearBatchProgress: true,
        error: 'Batch download encountered error: $e',
      );
      return OfflineFlightBatchResult(
        total: items.length,
        downloaded: 0,
        skipped: 0,
        failed: items.length,
      );
    }
  }
}

final storageNotifierProvider =
    StateNotifierProvider<StorageNotifier, StorageState>((ref) {
  final repo = ref.watch(storageRepositoryProvider);
  return StorageNotifier(repo);
});
