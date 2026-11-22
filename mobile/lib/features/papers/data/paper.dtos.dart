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
    this.authorityScore = 0.0,
    this.isSeminal = false,
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
  final double authorityScore;
  final bool isSeminal;

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
        authorityScore: authorityScore,
        isSeminal: isSeminal,
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

class AuthorDetailDto {
  const AuthorDetailDto({
    required this.id,
    required this.displayName,
    required this.nameNormalized,
    this.orcid,
    this.hIndex,
    this.affiliations = const [],
    this.paperCount = 0,
    this.citationCount = 0,
    this.metadata = const {},
  });

  final String id;
  final String displayName;
  final String nameNormalized;
  final String? orcid;
  final int? hIndex;
  final List<String> affiliations;
  final int paperCount;
  final int citationCount;
  final Map<String, dynamic> metadata;

  factory AuthorDetailDto.fromJson(Map<String, dynamic> json) {
    return AuthorDetailDto(
      id: json['id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      nameNormalized: json['name_normalized'] as String? ?? '',
      orcid: json['orcid'] as String?,
      hIndex: (json['h_index'] as num?)?.toInt(),
      affiliations: (json['affiliations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      paperCount: (json['paper_count'] as num?)?.toInt() ?? 0,
      citationCount: (json['citation_count'] as num?)?.toInt() ?? 0,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  AuthorDetail toDomain() {
    return AuthorDetail(
      id: id,
      displayName: displayName,
      nameNormalized: nameNormalized,
      orcid: orcid,
      hIndex: hIndex,
      affiliations: affiliations,
      paperCount: paperCount,
      citationCount: citationCount,
      metadata: metadata,
    );
  }
}

class AuthorWorksDto {
  const AuthorWorksDto({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<PaperSummaryDto> items;
  final int total;
  final int limit;
  final int offset;

  factory AuthorWorksDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return AuthorWorksDto(
      items: rawItems.map((e) => PaperSummaryDto.fromJson((e as Map).cast<String, dynamic>())).toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 20,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }

  AuthorWorks toDomain() {
    return AuthorWorks(
      items: items.map((e) => e.toDomain()).toList(),
      total: total,
      limit: limit,
      offset: offset,
    );
  }
}
