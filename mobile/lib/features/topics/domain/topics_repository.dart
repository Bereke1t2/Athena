import '../../papers/domain/paper.dart';

import 'topic.dart';

abstract interface class TopicsRepository {
  Future<TopicPage> list({String? kind, String? query, String? parent, String? cursor, int limit});

  Future<Topic> getBySlug(String slug);

  /// Papers filed under a topic; same filters as /research.
  Future<PaperListPage> listResearch(String slug, {String sort, String? cursor, int limit});
}

class PaperListPage {
  const PaperListPage({required this.items, required this.nextCursor});

  final List<PaperSummary> items;
  final String? nextCursor;
}
