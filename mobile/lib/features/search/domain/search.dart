import '../../papers/domain/paper.dart';

/// Sort orders whitelisted by GET /search.
enum SearchSort { relevance, newest, citations }

extension SearchSortWire on SearchSort {
  String get wireValue => name;
}

/// Search engines / retrieval modes supported by the platform.
enum SearchMode {
  hybrid,
  keyword,
  semantic,
  live;

  String get wireValue => name;

  String get label {
    switch (this) {
      case SearchMode.hybrid:
        return 'Hybrid AI';
      case SearchMode.keyword:
        return 'Keyword';
      case SearchMode.semantic:
        return 'Vector';
      case SearchMode.live:
        return 'Live Federated';
    }
  }
}

/// User-facing search filters; null means "not filtered".
class SearchFilters {
  const SearchFilters({
    required this.query,
    this.sort = SearchSort.relevance,
    this.mode = SearchMode.hybrid,
    this.topicSlug,
    this.fieldSlug,
    this.source,
    this.publishedAfter,
    this.publishedBefore,
    this.openAccess,
    this.minCitations,
    this.isLive = false,
  });

  final String query;
  final SearchSort sort;
  final SearchMode mode;
  final String? topicSlug;
  final String? fieldSlug;
  final String? source;
  final DateTime? publishedAfter;
  final DateTime? publishedBefore;
  final bool? openAccess;
  final int? minCitations;
  final bool isLive;

  SearchFilters copyWith({
    String? query,
    SearchSort? sort,
    SearchMode? mode,
    String? topicSlug,
    String? fieldSlug,
    String? source,
    DateTime? publishedAfter,
    DateTime? publishedBefore,
    bool? openAccess,
    int? minCitations,
    bool? isLive,
    bool clearDates = false,
    bool clearMinCitations = false,
  }) =>
      SearchFilters(
        query: query ?? this.query,
        sort: sort ?? this.sort,
        mode: mode ?? this.mode,
        topicSlug: topicSlug ?? this.topicSlug,
        fieldSlug: fieldSlug ?? this.fieldSlug,
        source: source ?? this.source,
        publishedAfter: clearDates ? null : (publishedAfter ?? this.publishedAfter),
        publishedBefore: clearDates ? null : (publishedBefore ?? this.publishedBefore),
        openAccess: openAccess ?? this.openAccess,
        minCitations: clearMinCitations ? null : (minCitations ?? this.minCitations),
        isLive: isLive ?? this.isLive,
      );
}

class SearchResult {
  const SearchResult({required this.score, required this.paper});

  final double score;
  final PaperSummary paper;
}

/// Per-provider telemetry from a federated live search; lets the UI show
/// which sources answered and which failed.
class SearchSourceStatus {
  const SearchSourceStatus({
    required this.slug,
    required this.ok,
    required this.papers,
    this.error,
  });

  final String slug;
  final bool ok;
  final int papers;
  final String? error;
}

class SearchPage {
  const SearchPage({
    required this.items,
    required this.nextCursor,
    required this.modeUsed,
    required this.totalEstimate,
    this.sources = const [],
    this.tookMs = 0,
  });

  final List<SearchResult> items;
  final String? nextCursor;

  /// Keyword until embeddings exist (Phase 4).
  final String modeUsed;

  /// -1 means the server did not estimate (pure-filter listings).
  final int totalEstimate;

  /// Sources consulted by the federated engine (live search only).
  final List<SearchSourceStatus> sources;

  /// Server-reported round trip in milliseconds.
  final int tookMs;
}
