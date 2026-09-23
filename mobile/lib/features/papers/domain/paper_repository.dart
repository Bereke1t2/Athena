import 'article_content.dart';
import 'paper.dart';

/// Repository interface lives in feature domain/ (conventions rule 4).
abstract interface class PaperRepository {
  Future<PaperDetail> getById(String id);
  Future<ArticleContent> getArticleContent(String id);
  Future<String> exportCitation(String id, String format);
  Future<List<PaperSummary>> getCitations(String id, {String direction = 'in', int limit = 20});
  Future<List<PaperSummary>> getRelated(String id, {int limit = 10});
}

