import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/feed.dart';
import '../domain/feed_repository.dart';
import 'feed.dtos.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<FeedPage> load({
    required FeedSection section,
    List<String> topics = const [],
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/feed',
        queryParameters: {
          'section': section.wireValue,
          if (topics.isNotEmpty) 'topic': topics.join(','),
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
      );
      final body = FeedListDto.fromJson(res.data!);
      return FeedPage(
        items: body.items.map((e) => e.toDomain()).toList(),
        nextCursor: body.meta.nextCursor,
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
