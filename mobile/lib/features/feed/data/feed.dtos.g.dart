// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed.dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FeedItemDto _$FeedItemDtoFromJson(Map<String, dynamic> json) => FeedItemDto(
      section: json['section'] as String,
      reason: json['reason'] as String? ?? '',
      paper: PaperSummaryDto.fromJson(json['paper'] as Map<String, dynamic>),
    );

FeedListDto _$FeedListDtoFromJson(Map<String, dynamic> json) => FeedListDto(
      items: (json['items'] as List<dynamic>)
          .map((e) => FeedItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: FeedMetaDto.fromJson(json['meta'] as Map<String, dynamic>),
    );

FeedMetaDto _$FeedMetaDtoFromJson(Map<String, dynamic> json) => FeedMetaDto(
      nextCursor: json['next_cursor'] as String?,
      limit: (json['limit'] as num).toInt(),
    );
