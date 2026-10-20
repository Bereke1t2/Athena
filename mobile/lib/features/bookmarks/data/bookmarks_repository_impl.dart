import 'package:dio/dio.dart';

import '../../papers/data/paper.dtos.dart';
import '../../papers/domain/paper.dart';
import '../domain/bookmarks_repository.dart';

class BookmarksRepositoryImpl implements BookmarksRepository {
  BookmarksRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<PaperSummary>> listBookmarks({int limit = 100}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/bookmarks',
      queryParameters: {'limit': limit},
    );
    final data = res.data!;
    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    return itemsRaw.map((raw) {
      final dto = PaperSummaryDto.fromJson((raw as Map).cast<String, dynamic>());
      return dto.toDomain();
    }).toList();
  }

  @override
  Future<void> addBookmark(String paperId, {String note = ''}) async {
    await _dio.post<void>(
      '/me/bookmarks',
      data: {'paper_id': paperId, 'note': note},
    );
  }

  @override
  Future<void> removeBookmark(String paperId) async {
    await _dio.delete<void>('/me/bookmarks/$paperId');
  }
}
