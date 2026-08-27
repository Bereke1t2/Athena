// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paper.dtos.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VenueDto _$VenueDtoFromJson(Map<String, dynamic> json) => VenueDto(
      name: json['name'] as String,
      type: json['type'] as String?,
    );

PaperSummaryDto _$PaperSummaryDtoFromJson(Map<String, dynamic> json) =>
    PaperSummaryDto(
      id: json['id'] as String,
      title: json['title'] as String,
      abstract: json['abstract'] as String?,
      publicationDate: json['publication_date'] == null
          ? null
          : DateTime.parse(json['publication_date'] as String),
      publicationYear: (json['publication_year'] as num).toInt(),
      venue: VenueDto.fromJson(json['venue'] as Map<String, dynamic>),
      publicationType: json['publication_type'] as String,
      oaStatus: json['oa_status'] as String,
      isOpenAccess: json['is_open_access'] as bool,
      citedByCount: (json['cited_by_count'] as num).toInt(),
    );

AuthorLineDto _$AuthorLineDtoFromJson(Map<String, dynamic> json) =>
    AuthorLineDto(
      id: json['id'] as String,
      name: json['name'] as String,
      orcid: json['orcid'] as String?,
      affiliation: (json['affiliation'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

TopicLineDto _$TopicLineDtoFromJson(Map<String, dynamic> json) => TopicLineDto(
      slug: json['slug'] as String,
      name: json['name'] as String,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      isPrimary: json['is_primary'] as bool,
    );

VersionLineDto _$VersionLineDtoFromJson(Map<String, dynamic> json) =>
    VersionLineDto(
      kind: json['kind'] as String,
      url: json['url'] as String,
      isPreprint: json['is_preprint'] as bool? ?? false,
    );

PaperDetailDto _$PaperDetailDtoFromJson(Map<String, dynamic> json) =>
    PaperDetailDto(
      id: json['id'] as String,
      title: json['title'] as String,
      abstract: json['abstract'] as String?,
      publicationDate: json['publication_date'] == null
          ? null
          : DateTime.parse(json['publication_date'] as String),
      publicationYear: (json['publication_year'] as num).toInt(),
      venue: VenueDto.fromJson(json['venue'] as Map<String, dynamic>),
      publicationType: json['publication_type'] as String,
      oaStatus: json['oa_status'] as String,
      isOpenAccess: json['is_open_access'] as bool,
      citedByCount: (json['cited_by_count'] as num).toInt(),
      language: json['language'] as String?,
      license: json['license'] as String?,
      bestOaUrl: json['best_oa_url'] as String?,
      doi: json['doi'] as String?,
      arxivId: json['arxiv_id'] as String?,
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => AuthorLineDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      topics: (json['topics'] as List<dynamic>?)
              ?.map((e) => TopicLineDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      versions: (json['versions'] as List<dynamic>?)
          ?.map((e) => VersionLineDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      referenceCount: (json['reference_count'] as num).toInt(),
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
