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

/// Checks whether a URL points directly to a PDF resource.
bool isDirectPdfUrl(String url) {
  final lower = url.trim().toLowerCase();
  return lower.endsWith('.pdf') ||
      lower.contains('.pdf?') ||
      lower.contains('/pdf/') ||
      lower.contains('arxiv.org/pdf');
}

/// Best-effort PDF URL from stored identifiers/versions; null when the paper
/// has no plausible direct PDF link.
String? resolvePdfUrl(PaperDetail paper) {
  // 1. Prefer direct PDF links (arXiv is always a real PDF).
  if (paper.arxivId.isNotEmpty) {
    return 'https://arxiv.org/pdf/${paper.arxivId}';
  }
  // 2. Check bestOaUrl if it is a direct PDF.
  if (paper.bestOaUrl.isNotEmpty && isDirectPdfUrl(paper.bestOaUrl)) {
    return paper.bestOaUrl;
  }
  // 3. Check version candidates for a direct PDF link.
  for (final v in paper.versions) {
    if (v.url.isNotEmpty && isDirectPdfUrl(v.url)) {
      return v.url;
    }
  }
  return null;
}

/// Best-effort web URL (DOI / Open Access landing page / publisher / arXiv abstract)
/// for opening in a browser when a direct PDF is unavailable or to view publisher source.
String? resolveWebUrl(PaperDetail paper) {
  if (paper.doi.isNotEmpty) {
    final doi = paper.doi.trim();
    if (doi.startsWith('http://') || doi.startsWith('https://')) {
      return doi;
    }
    return 'https://doi.org/$doi';
  }
  if (paper.bestOaUrl.isNotEmpty) {
    return paper.bestOaUrl.trim();
  }
  for (final v in paper.versions) {
    if (v.url.isNotEmpty) {
      return v.url.trim();
    }
  }
  if (paper.arxivId.isNotEmpty) {
    return 'https://arxiv.org/abs/${paper.arxivId.trim()}';
  }
  return null;
}
