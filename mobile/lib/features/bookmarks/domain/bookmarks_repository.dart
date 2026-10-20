import '../../papers/domain/paper.dart';

abstract class BookmarksRepository {
  Future<List<PaperSummary>> listBookmarks({int limit = 100});
  Future<void> addBookmark(String paperId, {String note = ''});
  Future<void> removeBookmark(String paperId);
}
