import 'feed.dart';

abstract interface class FeedRepository {
  /// [topics] OR-filters the feed to the user's followed topics; empty means
  /// unfiltered.
  Future<FeedPage> load({
    required FeedSection section,
    List<String> topics = const [],
    String? cursor,
    int limit,
  });
}
