/// Formats byte counts into human-readable strings (e.g. 1.2 MB).
String formatStorageBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double count = bytes.toDouble();
  while (count >= 1024 && i < suffixes.length - 1) {
    count /= 1024;
    i++;
  }
  return '${count.toStringAsFixed(count >= 10 || i == 0 ? 0 : 1)} ${suffixes[i]}';
}

/// Disk and local storage breakdown for research materials and offline state.
class StorageBreakdown {
  const StorageBreakdown({
    required this.pdfBytes,
    required this.pdfCount,
    required this.searchHistoryCount,
    required this.annotationsCount,
  });

  final int pdfBytes;
  final int pdfCount;
  final int searchHistoryCount;
  final int annotationsCount;

  int get totalEstimatedBytes => pdfBytes + (searchHistoryCount * 120) + (annotationsCount * 512);

  String get formattedPdfSize => formatStorageBytes(pdfBytes);
  String get formattedTotalSize => formatStorageBytes(totalEstimatedBytes);
}

/// Result of an offline flight pack batch download operation.
class OfflineFlightBatchResult {
  const OfflineFlightBatchResult({
    required this.total,
    required this.downloaded,
    required this.skipped,
    required this.failed,
  });

  final int total;
  final int downloaded;
  final int skipped;
  final int failed;

  bool get isFullSuccess => failed == 0;
}
