// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topics_repository_impl.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TopicDto _$TopicDtoFromJson(Map<String, dynamic> json) => TopicDto(
      slug: json['slug'] as String,
      name: json['name'] as String,
      kind: json['kind'] as String,
      paperCountEstimate: (json['paper_count_estimate'] as num).toInt(),
      description: json['description'] as String? ?? '',
      parent: json['parent'] == null
          ? null
          : TopicParentDto.fromJson(json['parent'] as Map<String, dynamic>),
      children: (json['children'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

TopicParentDto _$TopicParentDtoFromJson(Map<String, dynamic> json) =>
    TopicParentDto(
      slug: json['slug'] as String,
      name: json['name'] as String,
    );

TopicListDto _$TopicListDtoFromJson(Map<String, dynamic> json) => TopicListDto(
      items: (json['items'] as List<dynamic>)
          .map((e) => TopicDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: TopicListMetaDto.fromJson(json['meta'] as Map<String, dynamic>),
    );

TopicListMetaDto _$TopicListMetaDtoFromJson(Map<String, dynamic> json) =>
    TopicListMetaDto(
      nextCursor: json['next_cursor'] as String?,
      limit: (json['limit'] as num).toInt(),
    );

PaperListDto _$PaperListDtoFromJson(Map<String, dynamic> json) => PaperListDto(
      items: (json['items'] as List<dynamic>)
          .map((e) => PaperSummaryDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: FeedMetaDto.fromJson(json['meta'] as Map<String, dynamic>),
    );
