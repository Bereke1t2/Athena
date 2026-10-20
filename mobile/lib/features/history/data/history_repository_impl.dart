import 'package:dio/dio.dart';

import '../../papers/data/paper.dtos.dart';
import '../domain/history_repository.dart';
import '../domain/reading_history.dart';

class HistoryRepositoryImpl implements HistoryRepository {
  HistoryRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ReadingProgress> recordProgress({
    required String paperId,
    required double progressPercent,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/me/history/progress',
      data: {
        'paper_id': paperId,
        'progress_percent': progressPercent,
      },
    );
    final data = res.data!;
    return ReadingProgress(
      paperId: data['paper_id'] as String,
      progressPercent: (data['progress_percent'] as num).toDouble(),
      completed: data['completed'] as bool? ?? false,
      lastReadAt: DateTime.tryParse(data['last_read_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<ReadingProgress> getProgress(String paperId) async {
    final res = await _dio.get<Map<String, dynamic>>('/me/history/progress/$paperId');
    final data = res.data!;
    return ReadingProgress(
      paperId: data['paper_id'] as String,
      progressPercent: (data['progress_percent'] as num).toDouble(),
      completed: data['completed'] as bool? ?? false,
      lastReadAt: DateTime.tryParse(data['last_read_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  @override
  Future<({List<HistoryEntry> items, String nextCursor})> listHistory({
    String? cursor,
    int limit = 20,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/history',
      queryParameters: {
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      },
    );
    final data = res.data!;
    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    final items = itemsRaw.map((raw) {
      final map = raw as Map<String, dynamic>;
      final paperDto = PaperSummaryDto.fromJson((map['paper'] as Map).cast<String, dynamic>());
      return HistoryEntry(
        paper: paperDto.toDomain(),
        progressPercent: (map['progress_percent'] as num).toDouble(),
        completed: map['completed'] as bool? ?? false,
        lastReadAt: DateTime.tryParse(map['last_read_at'] as String? ?? '') ?? DateTime.now(),
      );
    }).toList();
    final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
    return (items: items, nextCursor: (meta['next_cursor'] as String?) ?? '');
  }

  @override
  Future<void> clearHistory() async {
    await _dio.delete<void>('/me/history');
  }
}
