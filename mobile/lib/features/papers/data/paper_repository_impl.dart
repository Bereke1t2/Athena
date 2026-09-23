import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/article_content.dart';
import '../domain/paper.dart';
import '../domain/paper_repository.dart';
import 'paper.dtos.dart';

class PaperRepositoryImpl implements PaperRepository {
  PaperRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaperDetail> getById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/research/papers/$id');
      return PaperDetailDto.fromJson(res.data!).toDomain();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<ArticleContent> getArticleContent(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/research/papers/$id/reader');
      return ArticleContent.fromJson(res.data!);
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<String> exportCitation(String id, String format) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/research/papers/$id/export',
        queryParameters: {'format': format},
      );
      return res.data?['content'] as String? ?? '';
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<List<PaperSummary>> getCitations(
    String id, {
    String direction = 'in',
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/research/papers/$id/citations',
        queryParameters: {'direction': direction, 'limit': limit},
      );
      final items = res.data?['items'] as List<dynamic>? ?? [];
      return items
          .map((raw) => PaperSummaryDto.fromJson(raw as Map<String, dynamic>).toDomain())
          .toList();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<List<PaperSummary>> getRelated(String id, {int limit = 10}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/research/papers/$id/related',
        queryParameters: {'limit': limit},
      );
      final items = res.data?['items'] as List<dynamic>? ?? [];
      return items
          .map((raw) => PaperSummaryDto.fromJson(raw as Map<String, dynamic>).toDomain())
          .toList();
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}

