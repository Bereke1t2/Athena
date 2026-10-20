import 'reading_history.dart';

abstract class HistoryRepository {
  Future<ReadingProgress> recordProgress({
    required String paperId,
    required double progressPercent,
  });

  Future<ReadingProgress> getProgress(String paperId);

  Future<({List<HistoryEntry> items, String nextCursor})> listHistory({
    String? cursor,
    int limit = 20,
  });

  Future<void> clearHistory();
}
