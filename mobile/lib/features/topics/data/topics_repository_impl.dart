import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../../core/network/api_client.dart';
import '../../feed/data/feed.dtos.dart' show FeedMetaDto;
import '../../papers/data/paper.dtos.dart';
import '../domain/topic.dart';
import '../domain/topics_repository.dart';

part 'topics_repository_impl.g.dart';

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class TopicDto {
  const TopicDto({
    required this.slug,
    required this.name,
    required this.kind,
    required this.paperCountEstimate,
    this.description = '',
    this.parent,
    this.children = const [],
  });

  final String slug;
  final String name;
  final String kind;
  final String? description;
  final int paperCountEstimate;
  final TopicParentDto? parent;
  final List<String>? children;

  factory TopicDto.fromJson(Map<String, dynamic> json) => _$TopicDtoFromJson(json);

  Topic toDomain() => Topic(
        slug: slug,
        name: name,
        kind: kind,
        paperCountEstimate: paperCountEstimate,
        description: description ?? '',
        parentSlug: parent?.slug,
        parentName: parent?.name,
        children: children ?? const [],
      );
}

@JsonSerializable(createToJson: false)
class TopicParentDto {
  const TopicParentDto({required this.slug, required this.name});

  final String slug;
  final String name;

  factory TopicParentDto.fromJson(Map<String, dynamic> json) => _$TopicParentDtoFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class TopicListDto {
  const TopicListDto({required this.items, required this.meta});

  final List<TopicDto> items;
  final TopicListMetaDto meta;

  factory TopicListDto.fromJson(Map<String, dynamic> json) => _$TopicListDtoFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class TopicListMetaDto {
  const TopicListMetaDto({this.nextCursor, required this.limit});

  final String? nextCursor;
  final int limit;

  factory TopicListMetaDto.fromJson(Map<String, dynamic> json) => _$TopicListMetaDtoFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class PaperListDto {
  const PaperListDto({required this.items, required this.meta});

  final List<PaperSummaryDto> items;
  final FeedMetaDto meta;

  factory PaperListDto.fromJson(Map<String, dynamic> json) => _$PaperListDtoFromJson(json);
}

class TopicsRepositoryImpl implements TopicsRepository {
  TopicsRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<TopicPage> list({
    String? kind,
    String? query,
    String? parent,
    String? cursor,
    int limit = 50,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/topics',
        queryParameters: {
          if (kind != null && kind.isNotEmpty) 'kind': kind,
          if (query != null && query.isNotEmpty) 'q': query,
          if (parent != null && parent.isNotEmpty) 'parent': parent,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
      );
      final body = TopicListDto.fromJson(res.data!);
      return TopicPage(
        items: body.items.map((e) => e.toDomain()).toList(),
        nextCursor: body.meta.nextCursor,
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<Topic> getBySlug(String slug) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/topics/$slug');
      return TopicDto.fromJson(res.data!).toDomain();
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<PaperListPage> listResearch(String slug, {String sort = 'relevance', String? cursor, int limit = 20}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/topics/$slug/research',
        queryParameters: {
          'sort': sort,
          if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
          'limit': limit,
        },
      );
      final body = PaperListDto.fromJson(res.data!);
      return PaperListPage(
        items: body.items.map((e) => e.toDomain()).toList(),
        nextCursor: body.meta.nextCursor,
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
