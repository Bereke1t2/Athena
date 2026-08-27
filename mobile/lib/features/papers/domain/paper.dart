/// Paper summary shape served by list endpoints (/research/papers, /feed,
/// /search, /topics/{slug}/research). Field-for-field with the backend's
/// `paperSummaryDTO`.
class PaperSummary {
  const PaperSummary({
    required this.id,
    required this.title,
    this.abstract,
    required this.publishedOn,
    required this.year,
    required this.venueName,
    required this.publicationType,
    required this.oaStatus,
    required this.isOpenAccess,
    required this.citedByCount,
  });

  final String id;
  final String title;
  final String? abstract;
  final DateTime? publishedOn;
  final int year;
  final String venueName;
  final String publicationType;
  final String oaStatus;
  final bool isOpenAccess;
  final int citedByCount;
}

class AuthorLine {
  const AuthorLine({required this.id, required this.name, this.orcid, this.affiliations = const []});

  final String id;
  final String name;
  final String? orcid;
  final List<String> affiliations;
}

class TopicLine {
  const TopicLine({
    required this.slug,
    required this.name,
    required this.score,
    required this.isPrimary,
  });

  final String slug;
  final String name;
  final double score;
  final bool isPrimary;
}

class VersionLine {
  const VersionLine({required this.kind, required this.url, required this.isPreprint});

  final String kind;
  final String url;
  final bool isPreprint;
}

/// Full detail served by GET /research/papers/{id}.
class PaperDetail {
  const PaperDetail({
    required this.summary,
    required this.language,
    required this.license,
    required this.bestOaUrl,
    required this.doi,
    required this.arxivId,
    required this.authors,
    required this.topics,
    required this.versions,
    required this.referenceCount,
    required this.sources,
  });

  final PaperSummary summary;
  final String language;
  final String license;
  final String bestOaUrl;
  final String doi;
  final String arxivId;
  final List<AuthorLine> authors;
  final List<TopicLine> topics;
  final List<VersionLine> versions;
  final int referenceCount;
  final List<String> sources;

  String get title => summary.title;
}
