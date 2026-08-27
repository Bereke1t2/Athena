import 'package:json_annotation/json_annotation.dart';

import '../domain/paper.dart';

part 'paper.dtos.g.dart';

/// API DTOs mirror the backend wire format 1:1 (snake_case) and never leak
/// above the data layer (conventions rule 3).
@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class VenueDto {
  const VenueDto({required this.name, this.type});

  final String name;
  final String? type;

  factory VenueDto.fromJson(Map<String, dynamic> json) => _$VenueDtoFromJson(json);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class PaperSummaryDto {
  const PaperSummaryDto({
    required this.id,
    required this.title,
    this.abstract,
    this.publicationDate,
    required this.publicationYear,
    required this.venue,
    required this.publicationType,
    required this.oaStatus,
    required this.isOpenAccess,
    required this.citedByCount,
  });

  final String id;
  final String title;
  final String? abstract;
  final DateTime? publicationDate;
  final int publicationYear;
  final VenueDto venue;
  final String publicationType;
  final String oaStatus;
  final bool isOpenAccess;
  final int citedByCount;

  factory PaperSummaryDto.fromJson(Map<String, dynamic> json) => _$PaperSummaryDtoFromJson(json);

  PaperSummary toDomain() => PaperSummary(
        id: id,
        title: title,
        abstract: (abstract == null || abstract!.trim().isEmpty) ? null : abstract,
        publishedOn: publicationDate?.toUtc(),
        year: publicationYear,
        venueName: venue.name,
        publicationType: publicationType,
        oaStatus: oaStatus,
        isOpenAccess: isOpenAccess,
        citedByCount: citedByCount,
      );
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class AuthorLineDto {
  const AuthorLineDto({required this.id, required this.name, this.orcid, this.affiliation});

  final String id;
  final String name;
  final String? orcid;

  final List<String>? affiliation;

  factory AuthorLineDto.fromJson(Map<String, dynamic> json) => _$AuthorLineDtoFromJson(json);

  AuthorLine toDomain() => AuthorLine(
        id: id,
        name: name,
        orcid: orcid,
        affiliations: affiliation ?? const [],
      );
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class TopicLineDto {
  const TopicLineDto({
    required this.slug,
    required this.name,
    this.score = 0,
    required this.isPrimary,
  });

  final String slug;
  final String name;
  final double score;
  final bool isPrimary;

  factory TopicLineDto.fromJson(Map<String, dynamic> json) => _$TopicLineDtoFromJson(json);

  TopicLine toDomain() =>
      TopicLine(slug: slug, name: name, score: score, isPrimary: isPrimary);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class VersionLineDto {
  const VersionLineDto({required this.kind, required this.url, this.isPreprint = false});

  final String kind;
  final String url;
  final bool isPreprint;

  factory VersionLineDto.fromJson(Map<String, dynamic> json) => _$VersionLineDtoFromJson(json);

  VersionLine toDomain() => VersionLine(kind: kind, url: url, isPreprint: isPreprint);
}

@JsonSerializable(createToJson: false, fieldRename: FieldRename.snake)
class PaperDetailDto {
  const PaperDetailDto({
    required this.id,
    required this.title,
    this.abstract,
    this.publicationDate,
    required this.publicationYear,
    required this.venue,
    required this.publicationType,
    required this.oaStatus,
    required this.isOpenAccess,
    required this.citedByCount,
    this.language,
    this.license,
    this.bestOaUrl,
    this.doi,
    this.arxivId,
    this.authors = const [],
    this.topics = const [],
    this.versions,
    required this.referenceCount,
    this.sources = const [],
  });

  final String id;
  final String title;
  final String? abstract;
  final DateTime? publicationDate;
  final int publicationYear;
  final VenueDto venue;
  final String publicationType;
  final String oaStatus;
  final bool isOpenAccess;
  final int citedByCount;
  final String? language;
  final String? license;
  final String? bestOaUrl;
  final String? doi;
  final String? arxivId;
  final List<AuthorLineDto>? authors;
  final List<TopicLineDto>? topics;
  final List<VersionLineDto>? versions;
  final int referenceCount;
  final List<String>? sources;

  factory PaperDetailDto.fromJson(Map<String, dynamic> json) => _$PaperDetailDtoFromJson(json);

  PaperDetail toDomain() => PaperDetail(
        summary: PaperSummary(
          id: id,
          title: title,
          abstract: (abstract == null || abstract!.trim().isEmpty) ? null : abstract,
          publishedOn: publicationDate?.toUtc(),
          year: publicationYear,
          venueName: venue.name,
          publicationType: publicationType,
          oaStatus: oaStatus,
          isOpenAccess: isOpenAccess,
          citedByCount: citedByCount,
        ),
        language: language ?? '',
        license: license ?? '',
        bestOaUrl: bestOaUrl ?? '',
        doi: doi ?? '',
        arxivId: arxivId ?? '',
        authors: (authors ?? const []).map((a) => a.toDomain()).toList(),
        topics: (topics ?? const []).map((t) => t.toDomain()).toList(),
        versions: (versions ?? const []).map((v) => v.toDomain()).toList(),
        referenceCount: referenceCount,
        sources: sources ?? const [],
      );
}
