import 'package:athena/core/di.dart';
import 'package:athena/features/follows/domain/follow_models.dart';
import 'package:athena/features/follows/domain/follows_repository.dart';
import 'package:athena/features/follows/presentation/follows_notifier.dart';
import 'package:athena/features/papers/domain/article_content.dart';
import 'package:athena/features/papers/domain/audio_playback.dart';
import 'package:athena/features/papers/domain/citation_graph.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/papers/domain/paper_repository.dart';
import 'package:athena/features/papers/presentation/author_detail_notifier.dart';
import 'package:athena/features/papers/presentation/author_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthorPaperRepo implements PaperRepository {
  _FakeAuthorPaperRepo({required this.author, required this.works});

  final AuthorDetail author;
  final List<PaperSummary> works;
  String? lastSort;

  @override
  Future<AuthorDetail> getAuthorById(String id) async => author;

  @override
  Future<AuthorWorks> getAuthorPapers(
    String id, {
    String sort = 'citations',
    int limit = 20,
    int offset = 0,
  }) async {
    lastSort = sort;
    final list = List.of(works);
    if (sort == 'title') {
      list.sort((a, b) => a.title.compareTo(b.title));
    } else if (sort == 'recent') {
      list.sort((a, b) => b.year.compareTo(a.year));
    } else {
      list.sort((a, b) => b.citedByCount.compareTo(a.citedByCount));
    }
    return AuthorWorks(items: list, total: list.length, limit: limit, offset: offset);
  }

  @override
  Future<PaperDetail> getById(String id) => throw UnimplementedError();

  @override
  Future<ArticleContent> getArticleContent(String id) => throw UnimplementedError();

  @override
  Future<String> exportCitation(String id, String format) => throw UnimplementedError();

  @override
  Future<List<PaperSummary>> getCitations(String id, {String direction = 'in', int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<List<PaperSummary>> getRelated(String id, {int limit = 10}) => throw UnimplementedError();

  @override
  Future<CitationGraph> getCitationGraph(String id, {int depth = 1, int limit = 25}) =>
      throw UnimplementedError();

  @override
  Future<AudioTrack> synthesizeAudio(String id, {String voice = 'Alloy', String length = 'standard', String focus = 'general'}) =>
      throw UnimplementedError();
}

class _FakeFollowsRepo implements FollowsRepository {
  final Map<String, AuthorFollow> followed = {};

  @override
  Future<TopicFollow> followTopic(String slug, {bool notify = true}) async =>
      TopicFollow(topicId: 't-1', topicSlug: slug, topicName: slug, notify: notify, createdAt: DateTime.now());

  @override
  Future<void> unfollowTopic(String slug) async {}

  @override
  Future<List<TopicFollow>> getFollowedTopics() async => [];

  @override
  Future<AuthorFollow> followAuthor(String authorId) async {
    final af = AuthorFollow(authorId: authorId, authorName: 'Author $authorId', createdAt: DateTime.now());
    followed[authorId] = af;
    return af;
  }

  @override
  Future<void> unfollowAuthor(String authorId) async {
    followed.remove(authorId);
  }

  @override
  Future<List<AuthorFollow>> getFollowedAuthors() async => followed.values.toList();
}

void main() {
  const testAuthor = AuthorDetail(
    id: 'author-101',
    displayName: 'Yann LeCun',
    nameNormalized: 'yann lecun',
    orcid: '0000-0002-1234-5678',
    hIndex: 140,
    affiliations: ['New York University', 'Meta AI'],
    paperCount: 250,
    citationCount: 300000,
  );

  final testPapers = [
    PaperSummary(
      id: 'p-1',
      title: 'Gradient-Based Learning Applied to Document Recognition',
      publishedOn: DateTime(1998, 11, 1),
      year: 1998,
      venueName: 'Proceedings of the IEEE',
      publicationType: 'article',
      oaStatus: 'gold',
      isOpenAccess: true,
      citedByCount: 45000,
      isSeminal: true,
    ),
    PaperSummary(
      id: 'p-2',
      title: 'Deep Learning',
      publishedOn: DateTime(2015, 5, 28),
      year: 2015,
      venueName: 'Nature',
      publicationType: 'article',
      oaStatus: 'bronze',
      isOpenAccess: true,
      citedByCount: 60000,
      isSeminal: true,
    ),
  ];

  group('AuthorDetailNotifier', () {
    test('loads author detail and works catalog successfully', () async {
      final repo = _FakeAuthorPaperRepo(author: testAuthor, works: testPapers);
      final container = ProviderContainer(
        overrides: [
          paperRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authorDetailProvider('author-101').notifier);
      await pumpEventQueue();

      final state = container.read(authorDetailProvider('author-101'));
      expect(state.isLoading, isFalse);
      expect(state.author?.displayName, equals('Yann LeCun'));
      expect(state.author?.hIndex, equals(140));
      expect(state.works.length, equals(2));
      expect(state.totalWorks, equals(2));

      // Test sort change to 'recent'
      await notifier.setSort('recent');
      await pumpEventQueue();

      final sortedState = container.read(authorDetailProvider('author-101'));
      expect(sortedState.sort, equals('recent'));
      expect(repo.lastSort, equals('recent'));
      expect(sortedState.works.first.year, equals(2015));
    });
  });

  group('AuthorDetailScreen Widget Tests', () {
    testWidgets('renders author profile card, metrics, and works list', (tester) async {
      final repo = _FakeAuthorPaperRepo(author: testAuthor, works: testPapers);
      final followsRepo = _FakeFollowsRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paperRepositoryProvider.overrideWithValue(repo),
            followsRepositoryProvider.overrideWithValue(followsRepo),
            followsNotifierProvider.overrideWith(
              (ref) => FollowsNotifier(followsRepo, true),
            ),
          ],
          child: const MaterialApp(
            home: AuthorDetailScreen(
              id: 'author-101',
              initialName: 'Yann LeCun',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Author Info
      expect(find.text('Yann LeCun'), findsWidgets);
      expect(find.text('New York University · Meta AI'), findsOneWidget);
      expect(find.text('ORCID: 0000-0002-1234-5678'), findsOneWidget);

      // Verify Metrics
      expect(find.text('Publications'), findsOneWidget);
      expect(find.text('250'), findsOneWidget);
      expect(find.text('300.0k'), findsOneWidget);
      expect(find.text('H-Index'), findsOneWidget);
      expect(find.text('140'), findsOneWidget);

      // Verify Works Catalog & Sort Chips (Citations appears in metric box + sort chip)
      expect(find.text('WORKS CATALOG (2)'), findsOneWidget);
      expect(find.text('Citations'), findsNWidgets(2));
      expect(find.text('Newest'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);

      // Verify Paper Titles
      expect(find.text('Gradient-Based Learning Applied to Document Recognition'), findsOneWidget);
      expect(find.text('Deep Learning'), findsOneWidget);

      // Verify Follow button toggle
      expect(find.text('Follow Author'), findsOneWidget);
      await tester.tap(find.text('Follow Author'));
      await tester.pumpAndSettle();
      expect(find.text('Following'), findsOneWidget);
    });
  });
}
