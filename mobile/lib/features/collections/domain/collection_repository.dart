import 'collection.dart';

abstract class CollectionRepository {
  Future<List<Collection>> listCollections();
  Future<(Collection, List<CollectionPaper>)> getCollection(String id);
  Future<Collection> createCollection({
    required String name,
    String description = '',
    String color = '#6366F1',
    bool isPublic = false,
  });
  Future<Collection> updateCollection(
    String id, {
    String? name,
    String? description,
    String? color,
    bool? isPublic,
  });
  Future<void> deleteCollection(String id);
  Future<void> addPaper(String collectionId, String paperId, {String note = ''});
  Future<void> removePaper(String collectionId, String paperId);
  Future<String> exportCollection(String collectionId, {String format = 'bibtex'});
  Future<List<PaperMembership>> getPaperMemberships(String paperId);
}
