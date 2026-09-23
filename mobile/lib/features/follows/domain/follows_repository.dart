import 'follow_models.dart';

abstract class FollowsRepository {
  Future<TopicFollow> followTopic(String slug, {bool notify = true});
  Future<void> unfollowTopic(String slug);
  Future<List<TopicFollow>> getFollowedTopics();

  Future<AuthorFollow> followAuthor(String authorId);
  Future<void> unfollowAuthor(String authorId);
  Future<List<AuthorFollow>> getFollowedAuthors();
}
