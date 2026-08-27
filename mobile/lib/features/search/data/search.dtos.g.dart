// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search.dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScoredPaperDto _$ScoredPaperDtoFromJson(Map<String, dynamic> json) =>
    ScoredPaperDto(
      score: (json['score'] as num).toDouble(),
      paper: PaperSummaryDto.fromJson(json['paper'] as Map<String, dynamic>),
    );

SourceStatusDto _$SourceStatusDtoFromJson(Map<String, dynamic> json) =>
    SourceStatusDto(
      slug: json['slug'] as String,
      ok: json['ok'] as bool,
      papers: (json['papers'] as num).toInt(),
      error: json['error'] as String?,
    );

SearchListDto _$SearchListDtoFromJson(Map<String, dynamic> json) =>
    SearchListDto(
      items: (json['items'] as List<dynamic>)
          .map((e) => ScoredPaperDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      meta: SearchMetaDto.fromJson(json['meta'] as Map<String, dynamic>),
    );

SearchMetaDto _$SearchMetaDtoFromJson(Map<String, dynamic> json) =>
    SearchMetaDto(
      nextCursor: json['next_cursor'] as String?,
      modeUsed: json['mode_used'] as String?,
      tookMs: (json['took_ms'] as num?)?.toInt() ?? 0,
      totalEstimate: (json['total_estimate'] as num?)?.toInt() ?? -1,
      sources: (json['sources'] as List<dynamic>?)
          ?.map((e) => SourceStatusDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
