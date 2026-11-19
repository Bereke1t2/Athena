import '../../papers/domain/pdf_repository.dart';
import 'storage_models.dart';

/// Repository interface managing local device storage, offline research materials,
/// and flight pack pre-caching.
abstract class StorageRepository {
  /// Computes disk and state usage breakdown across documents and cache.
  Future<StorageBreakdown> getStorageBreakdown();

  /// Lists all locally cached research paper PDFs.
  Future<List<CachedPdfInfo>> listCachedPdfs();

  /// Deletes a specific cached PDF from persistent device storage.
  Future<void> deletePdf(String paperId);

  /// Clears all downloaded research paper PDFs.
  Future<void> clearAllPdfs();

  /// Clears recent local search history queries.
  Future<void> clearSearchHistory();

  /// Clears all local search history and cached PDFs.
  Future<void> clearAllStorage();

  /// Pre-caches a list of research papers for offline flight reading.
  Future<OfflineFlightBatchResult> downloadFlightPack(
    List<(String paperId, String pdfUrl)> items, {
    void Function(int completed, int total)? onProgress,
  });
}
