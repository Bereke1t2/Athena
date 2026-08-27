import 'package:json_annotation/json_annotation.dart';

import '../../papers/data/paper.dtos.dart';
import '../domain/feed.dart';

part 'feed.dtos.g.dart';

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class FeedItemDto {
  const FeedItemDto({required this.section, this.reason = '', required this.paper});

  final String section;
  final String reason;
  final PaperSummaryDto paper;

  factory FeedItemDto.fromJson(Map<String, dynamic> json) => _$FeedItemDtoFromJson(json);

  FeedItem toDomain() => FeedItem(
        section: FeedSection.values.firstWhere(
          (s) => s.wireValue == section,
          orElse: () => FeedSection.latest,
        ),
        reason: reason,
        paper: paper.toDomain(),
      );
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class FeedListDto {
  const FeedListDto({required this.items, required this.meta});

  final List<FeedItemDto> items;
  final FeedMetaDto meta;

  factory FeedListDto.fromJson(Map<String, dynamic> json) => _$FeedListDtoFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class FeedMetaDto {
  const FeedMetaDto({this.nextCursor, required this.limit});

  final String? nextCursor;
  final int limit;

  factory FeedMetaDto.fromJson(Map<String, dynamic> json) => _$FeedMetaDtoFromJson(json);
}
