import 'package:athena/features/follows/domain/follow_models.dart';
import 'package:athena/features/follows/domain/follows_repository.dart';
import 'package:athena/features/follows/presentation/follows_notifier.dart';
import 'package:athena/features/topics/domain/topic.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFollowsRepository implements FollowsRepository {
  final List<TopicFollow> topics = [];
  final List<AuthorFollow> authors = [];
  final List<String> followedTopicCalls = [];
  final List<String> unfollowedTopicCalls = [];

  @override
  Future<TopicFollow> followTopic(String slug, {bool notify = true}) async {
    followedTopicCalls.add(slug);
    final follow = TopicFollow(
      topicId: slug,
      topicSlug: slug,
      topicName: Topic.displayNameForSlug(slug),
      notify: notify,
      createdAt: DateTime.now(),
    );
    topics.add(follow);
    return follow;
  }

  @override
  Future<void> unfollowTopic(String slug) async {
    unfollowedTopicCalls.add(slug);
    topics.removeWhere((t) => t.topicSlug == slug);
  }

  @override
  Future<List<TopicFollow>> getFollowedTopics() async {
    return List.unmodifiable(topics);
  }

  @override
  Future<AuthorFollow> followAuthor(String authorId) async {
    final follow = AuthorFollow(authorId: authorId, authorName: 'Author $authorId', createdAt: DateTime.now());
    authors.add(follow);
    return follow;
  }

  @override
  Future<void> unfollowAuthor(String authorId) async {
    authors.removeWhere((a) => a.authorId == authorId);
  }

  @override
  Future<List<AuthorFollow>> getFollowedAuthors() async {
    return List.unmodifiable(authors);
  }
}

void main() {
  group('FollowsNotifier Guest Mode', () {
    test('initializes with guest onboarding topics', () {
      final fakeRepo = _FakeFollowsRepository();
      final notifier = FollowsNotifier(
        fakeRepo,
        false,
        guestTopicSlugs: ['machine-learning', 'quantum-computing'],
      );

      expect(notifier.state.isGuest, isTrue);
      expect(notifier.state.followedTopics.length, 2);
      expect(notifier.state.isTopicFollowed('machine-learning'), isTrue);
      expect(notifier.state.isTopicFollowed('quantum-computing'), isTrue);
      expect(notifier.state.isTopicFollowed('biology'), isFalse);
    });

    test('toggles guest topics and notifies callback without network calls', () async {
      final fakeRepo = _FakeFollowsRepository();
      List<String>? updatedSlugs;
      final notifier = FollowsNotifier(
        fakeRepo,
        false,
        guestTopicSlugs: ['machine-learning'],
        onGuestTopicsChanged: (slugs) {
          updatedSlugs = slugs;
        },
      );

      // Follow new topic
      await notifier.toggleTopicFollow('artificial-intelligence', 'Artificial Intelligence');
      expect(notifier.state.isTopicFollowed('artificial-intelligence'), isTrue);
      expect(updatedSlugs, contains('artificial-intelligence'));
      expect(fakeRepo.followedTopicCalls, isEmpty); // No backend calls for guest

      // Unfollow existing topic
      await notifier.toggleTopicFollow('machine-learning', 'Machine Learning');
      expect(notifier.state.isTopicFollowed('machine-learning'), isFalse);
      expect(updatedSlugs, isNot(contains('machine-learning')));
    });
  });

  group('FollowsNotifier Authenticated Mode', () {
    test('syncs guest topics upon initialization and loads from repository', () async {
      final fakeRepo = _FakeFollowsRepository();
      final notifier = FollowsNotifier(
        fakeRepo,
        true,
        guestTopicSlugs: ['neuroscience', 'robotics'],
      );

      // Wait for async loadAll in constructor
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(notifier.state.isGuest, isFalse);
      expect(fakeRepo.followedTopicCalls, containsAll(['neuroscience', 'robotics']));
      expect(notifier.state.followedTopics.length, 2);
    });

    test('toggles topics and authors through repository', () async {
      final fakeRepo = _FakeFollowsRepository();
      final notifier = FollowsNotifier(fakeRepo, true);

      // Follow topic
      await notifier.toggleTopicFollow('data-science', 'Data Science');
      expect(fakeRepo.followedTopicCalls, contains('data-science'));
      expect(notifier.state.isTopicFollowed('data-science'), isTrue);

      // Unfollow topic
      await notifier.toggleTopicFollow('data-science', 'Data Science');
      expect(fakeRepo.unfollowedTopicCalls, contains('data-science'));
      expect(notifier.state.isTopicFollowed('data-science'), isFalse);
    });
  });
}
