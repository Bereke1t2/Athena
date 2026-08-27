import 'package:json_annotation/json_annotation.dart';

import '../../papers/data/paper.dtos.dart';
import '../domain/search.dart';

part 'search.dtos.g.dart';

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class ScoredPaperDto {
  const ScoredPaperDto({required this.score, required this.paper});

  final double score;
  final PaperSummaryDto paper;

  factory ScoredPaperDto.fromJson(Map<String, dynamic> json) => _$ScoredPaperDtoFromJson(json);

  SearchResult toDomain() => SearchResult(score: score, paper: paper.toDomain());
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class SourceStatusDto {
  const SourceStatusDto({
    required this.slug,
    required this.ok,
    required this.papers,
    this.error,
  });

  final String slug;
  final bool ok;
  final int papers;
  final String? error;

  factory SourceStatusDto.fromJson(Map<String, dynamic> json) => _$SourceStatusDtoFromJson(json);

  SearchSourceStatus toDomain() =>
      SearchSourceStatus(slug: slug, ok: ok, papers: papers, error: error);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class SearchListDto {
  const SearchListDto({required this.items, required this.meta});

  final List<ScoredPaperDto> items;
  final SearchMetaDto meta;

  factory SearchListDto.fromJson(Map<String, dynamic> json) => _$SearchListDtoFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class SearchMetaDto {
  const SearchMetaDto({
    this.nextCursor,
    this.modeUsed,
    this.tookMs = 0,
    this.totalEstimate = -1,
    this.sources,
  });

  final String? nextCursor;

  /// Live search has no mode; corpus search always reports one.
  final String? modeUsed;

  final int tookMs;

  final int totalEstimate;

  final List<SourceStatusDto>? sources;

  factory SearchMetaDto.fromJson(Map<String, dynamic> json) => _$SearchMetaDtoFromJson(json);
}
