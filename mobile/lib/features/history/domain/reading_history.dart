import '../../papers/domain/paper.dart';

class ReadingProgress {
  const ReadingProgress({
    required this.paperId,
    required this.progressPercent,
    required this.completed,
    required this.lastReadAt,
  });

  final String paperId;
  final double progressPercent;
  final bool completed;
  final DateTime lastReadAt;
}

class HistoryEntry {
  const HistoryEntry({
    required this.paper,
    required this.progressPercent,
    required this.completed,
    required this.lastReadAt,
  });

  final PaperSummary paper;
  final double progressPercent;
  final bool completed;
  final DateTime lastReadAt;
}
