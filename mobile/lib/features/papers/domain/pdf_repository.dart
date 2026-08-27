import 'paper.dart';

/// PDF access port: resolves full-text URLs and caches downloads locally
/// (data layer owns dio/file handling).
abstract interface class PdfRepository {
  /// Returns a cached local path for the paper's PDF, downloading on first
  /// use. Progress reports (receivedBytes, totalBytes-or-null).
  Future<String> download(String paperId, String url,
      {void Function(int received, int? total)? onProgress});

  /// Delete cached PDF for [paperId] so next [download] re-fetches.
  Future<void> deleteCache(String paperId);
}

/// Best-effort PDF URL from stored identifiers/versions; null when the paper
/// has no plausible full-text link.
String? resolvePdfUrl(PaperDetail paper) {
  // Prefer direct PDF links (arXiv is always a real PDF).
  if (paper.arxivId.isNotEmpty) {
    return 'https://arxiv.org/pdf/${paper.arxivId}';
  }
  // Check bestOaUrl — only accept if it looks like a direct PDF link.
  if (paper.bestOaUrl.isNotEmpty) {
    final lower = paper.bestOaUrl.toLowerCase();
    if (lower.endsWith('.pdf') || lower.contains('/pdf/')) {
      return paper.bestOaUrl;
    }
  }
  return null;
}
