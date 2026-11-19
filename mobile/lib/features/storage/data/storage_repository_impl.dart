import '../../../core/prefs/user_preferences.dart';
import '../../papers/domain/pdf_repository.dart';
import '../domain/storage_models.dart';
import '../domain/storage_repository.dart';

class StorageRepositoryImpl implements StorageRepository {
  StorageRepositoryImpl(this._pdfRepo, [UserPreferences? prefs])
      : _prefs = prefs ?? UserPreferences.instance;

  final PdfRepository _pdfRepo;
  final UserPreferences _prefs;

  @override
  Future<StorageBreakdown> getStorageBreakdown() async {
    final pdfs = await _pdfRepo.listCachedPdfs();
    final pdfBytes = pdfs.fold<int>(0, (acc, p) => acc + p.sizeBytes);
    final searchHistoryCount = _prefs.searchHistory.length;

    // Approximate count of cached annotations stored locally in UserPreferences
    var annotationsCount = 0;
    for (final p in pdfs) {
      if (_prefs.getPaperAnnotations(p.paperId) != null) {
        annotationsCount++;
      }
    }

    return StorageBreakdown(
      pdfBytes: pdfBytes,
      pdfCount: pdfs.length,
      searchHistoryCount: searchHistoryCount,
      annotationsCount: annotationsCount,
    );
  }

  @override
  Future<List<CachedPdfInfo>> listCachedPdfs() => _pdfRepo.listCachedPdfs();

  @override
  Future<void> deletePdf(String paperId) => _pdfRepo.deleteCache(paperId);

  @override
  Future<void> clearAllPdfs() => _pdfRepo.clearAllPdfs();

  @override
  Future<void> clearSearchHistory() => _prefs.clearSearchHistory();

  @override
  Future<void> clearAllStorage() async {
    await _pdfRepo.clearAllPdfs();
    await _prefs.clearSearchHistory();
  }

  @override
  Future<OfflineFlightBatchResult> downloadFlightPack(
    List<(String paperId, String pdfUrl)> items, {
    void Function(int completed, int total)? onProgress,
  }) async {
    var downloaded = 0;
    var skipped = 0;
    var failed = 0;
    final total = items.length;

    for (var i = 0; i < items.length; i++) {
      final (paperId, url) = items[i];
      if (await _pdfRepo.isCached(paperId)) {
        skipped++;
      } else if (url.trim().isNotEmpty) {
        try {
          await _pdfRepo.download(paperId, url);
          downloaded++;
        } catch (_) {
          failed++;
        }
      } else {
        failed++;
      }
      onProgress?.call(downloaded + skipped + failed, total);
    }

    return OfflineFlightBatchResult(
      total: total,
      downloaded: downloaded,
      skipped: skipped,
      failed: failed,
    );
  }
}
