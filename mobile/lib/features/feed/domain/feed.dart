import '../../papers/domain/paper.dart';

/// One entry of GET /feed: a paper plus presentation metadata.
class FeedItem {
  const FeedItem({required this.section, required this.reason, required this.paper});

  final FeedSection section;

  /// Personalization rationale; empty for latest/trending.
  final String reason;
  final PaperSummary paper;
}

class FeedPage {
  const FeedPage({required this.items, required this.nextCursor});

  final List<FeedItem> items;
  final String? nextCursor;
}

/// Feed sections served by GET /feed. `recommended` is Phase 5 (auth).
enum FeedSection { latest, trending, recommended }

extension FeedSectionWire on FeedSection {
  String get wireValue => name;
}
