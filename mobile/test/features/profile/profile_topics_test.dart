import 'package:athena/features/follows/domain/follow_models.dart';
import 'package:athena/features/follows/domain/follows_repository.dart';
import 'package:athena/features/follows/presentation/follows_notifier.dart';
import 'package:athena/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFollowsRepo implements FollowsRepository {
  List<String> unfollowCalls = [];

  @override
  Future<TopicFollow> followTopic(String slug, {bool notify = true}) async {
    return TopicFollow(
      topicId: slug,
      topicSlug: slug,
      topicName: slug,
      notify: notify,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> unfollowTopic(String slug) async {
    unfollowCalls.add(slug);
  }

  @override
  Future<List<TopicFollow>> getFollowedTopics() async => [];

  @override
  Future<AuthorFollow> followAuthor(String authorId) async =>
      AuthorFollow(authorId: authorId, authorName: 'Author', createdAt: DateTime.now());

  @override
  Future<void> unfollowAuthor(String authorId) async {}

  @override
  Future<List<AuthorFollow>> getFollowedAuthors() async => [];
}

void main() {
  testWidgets('ProfileScreen renders followed topics and allows quick unfollow', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = _FakeFollowsRepo();
    final initialNotifier = FollowsNotifier(
      fakeRepo,
      false,
      guestTopicSlugs: ['machine-learning', 'quantum-computing'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          followsNotifierProvider.overrideWith((ref) => initialNotifier),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify section header and count badge
    expect(find.text('FOLLOWED TOPICS'), findsOneWidget);
    expect(find.text('Subscribed Areas'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Verify topic chips
    expect(find.text('Machine Learning'), findsOneWidget);
    expect(find.text('Quantum Computing'), findsOneWidget);

    // Tap ✕ on the first topic chip to unfollow
    final closeIcons = find.byIcon(Icons.close_rounded);
    expect(closeIcons, findsWidgets);
    await tester.tap(closeIcons.first);
    await tester.pumpAndSettle();

    // Count should decrement and Machine Learning should be removed
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Machine Learning'), findsNothing);
    expect(find.text('Quantum Computing'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders clean empty state when no topics followed', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = _FakeFollowsRepo();
    final emptyNotifier = FollowsNotifier(
      fakeRepo,
      false,
      guestTopicSlugs: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          followsNotifierProvider.overrideWith((ref) => emptyNotifier),
        ],
        child: const MaterialApp(
          home: ProfileScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('FOLLOWED TOPICS'), findsOneWidget);
    expect(find.text('No topics followed yet'), findsOneWidget);
    expect(find.text('Explore Topics'), findsOneWidget);
  });
}
