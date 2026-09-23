import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/follow_models.dart';
import '../domain/follows_repository.dart';

class FollowsRepositoryImpl implements FollowsRepository {
  FollowsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TopicFollow> followTopic(String slug, {bool notify = true}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/follows/topics',
        data: {'topic_slug': slug, 'notify': notify},
      );
      final data = res.data!;
      return TopicFollow(
        topicId: data['topic_id'] as String,
        topicSlug: data['topic_slug'] as String,
        topicName: data['topic_name'] as String,
        notify: data['notify'] as bool? ?? true,
        createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> unfollowTopic(String slug) async {
    try {
      await _dio.delete<void>('/me/follows/topics/$slug');
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<List<TopicFollow>> getFollowedTopics() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/follows/topics');
      final items = res.data?['items'] as List<dynamic>? ?? [];
      return items.map((raw) {
        final d = raw as Map<String, dynamic>;
        return TopicFollow(
          topicId: d['topic_id'] as String,
          topicSlug: d['topic_slug'] as String,
          topicName: d['topic_name'] as String,
          notify: d['notify'] as bool? ?? true,
          createdAt: DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<AuthorFollow> followAuthor(String authorId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/me/follows/authors',
        data: {'author_id': authorId},
      );
      final data = res.data!;
      return AuthorFollow(
        authorId: data['author_id'] as String,
        authorName: data['author_name'] as String,
        createdAt: DateTime.tryParse(data['created_at'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<void> unfollowAuthor(String authorId) async {
    try {
      await _dio.delete<void>('/me/follows/authors/$authorId');
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<List<AuthorFollow>> getFollowedAuthors() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/follows/authors');
      final items = res.data?['items'] as List<dynamic>? ?? [];
      return items.map((raw) {
        final d = raw as Map<String, dynamic>;
        return AuthorFollow(
          authorId: d['author_id'] as String,
          authorName: d['author_name'] as String,
          createdAt: DateTime.tryParse(d['created_at'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
