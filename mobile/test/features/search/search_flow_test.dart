import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/search/domain/search.dart';
import 'package:athena/features/search/domain/search_repository.dart';
import 'package:athena/features/search/presentation/search_screen.dart';
import 'package:athena/features/topics/domain/topic.dart';
import 'package:athena/features/topics/domain/topics_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSearchRepository implements SearchRepository {
  SearchFilters? lastFilters;

  @override
  Future<SearchPage> search(SearchFilters filters, {String? cursor, int limit = 20}) async {
    lastFilters = filters;
    if (filters.query == 'empty-corpus' && !filters.isLive) {
      return const SearchPage(
        items: [],
        nextCursor: null,
        modeUsed: 'corpus',
        totalEstimate: 0,
      );
    }
    return SearchPage(
      items: [
        SearchResult(
          score: 4.5,
          paper: PaperSummary(
            id: 'paper-1',
            title: 'Found Paper for ${filters.query}',
            abstract: 'Paper abstract content',
            publishedOn: DateTime(2025, 1, 1),
            year: 2025,
            venueName: 'NeurIPS',
            publicationType: 'conference_paper',
            oaStatus: 'gold',
            isOpenAccess: true,
            citedByCount: 42,
          ),
        ),
      ],
      nextCursor: null,
      modeUsed: filters.isLive ? 'live' : 'corpus',
      totalEstimate: 1,
      sources: filters.isLive
          ? const [
              SearchSourceStatus(slug: 'europepmc', ok: true, papers: 5),
              SearchSourceStatus(slug: 'arxiv', ok: true, papers: 10),
            ]
          : const [],
    );
  }
}

class _FakeTopicsRepository implements TopicsRepository {
  @override
  Future<TopicPage> list({
    String? kind,
    String? query,
    String? parent,
    String? cursor,
    int limit = 50,
  }) async {
    if (query != null && query.toLowerCase().contains('mach')) {
      return const TopicPage(
        items: [
          Topic(
            slug: 'machine-learning',
            name: 'Machine Learning',
            kind: 'field',
            paperCountEstimate: 1420,
            parentName: 'Computer Science',
          ),
        ],
        nextCursor: null,
      );
    }
    return const TopicPage(items: [], nextCursor: null);
  }

  @override
  Future<Topic> getBySlug(String slug) async => throw UnimplementedError();

  @override
  Future<PaperListPage> listResearch(String slug, {String sort = 'newest', String? cursor, int limit = 20}) async =>
      throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load();
  });

  testWidgets('SearchScreen accepts initialQuery and auto-submits', (tester) async {
    final fakeRepo = _FakeSearchRepository();
    final fakeTopics = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
          topicsRepositoryProvider.overrideWithValue(fakeTopics),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'transformers'),
        ),
      ),
    );

    // Initial pump & settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('transformers'), findsOneWidget);
    expect(find.text('Found Paper for transformers'), findsOneWidget);
    expect(fakeRepo.lastFilters?.query, 'transformers');
    expect(fakeRepo.lastFilters?.isLive, false);
  });

  testWidgets('SearchScreen toggles between Corpus and Live Web', (tester) async {
    final fakeRepo = _FakeSearchRepository();
    final fakeTopics = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
          topicsRepositoryProvider.overrideWithValue(fakeTopics),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'quantum'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(fakeRepo.lastFilters?.isLive, false);

    // Tap 'Live Web' chip
    await tester.tap(find.text('Live Web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeRepo.lastFilters?.isLive, true);
  });

  testWidgets('SearchScreen shows Web Search prompt on empty corpus', (tester) async {
    final fakeRepo = _FakeSearchRepository();
    final fakeTopics = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
          topicsRepositoryProvider.overrideWithValue(fakeTopics),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'empty-corpus'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Search Web'), findsOneWidget);

    // Tap the 'Search Web' fallback button
    await tester.tap(find.text('Search Web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeRepo.lastFilters?.isLive, true);
  });

  testWidgets('SearchScreen renders Europe PMC telemetry chip on live search', (tester) async {
    final fakeRepo = _FakeSearchRepository();
    final fakeTopics = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
          topicsRepositoryProvider.overrideWithValue(fakeTopics),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'crispr-cas9'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap 'Live Web' chip to trigger live mode
    await tester.tap(find.text('Live Web'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Europe PMC (5)'), findsOneWidget);
    expect(find.text('arXiv (10)'), findsOneWidget);
  });

  testWidgets('SearchScreen displays topic suggestions when typing query', (tester) async {
    final fakeRepo = _FakeSearchRepository();
    final fakeTopics = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
          topicsRepositoryProvider.overrideWithValue(fakeTopics),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Type query into search bar
    await tester.enterText(find.byType(SearchBar), 'mach');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify autocomplete suggestions appear
    expect(find.text('TOPIC & FIELD SUGGESTIONS'), findsOneWidget);
    expect(find.text('Machine Learning'), findsOneWidget);
    expect(find.text('1420 papers'), findsOneWidget);
    expect(find.text('Computer Science'), findsOneWidget);

    // Tap the suggestion
    await tester.tap(find.text('Machine Learning'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify search was submitted with the topic name
    expect(fakeRepo.lastFilters?.query, 'Machine Learning');
    expect(find.text('Found Paper for Machine Learning'), findsOneWidget);
  });

  testWidgets('SearchScreen displays and uses recent search history chips', (tester) async {
    final fakeRepo = _FakeSearchRepository();
    final fakeTopics = _FakeTopicsRepository();

    // Prime search history
    await UserPreferences.instance.addSearchHistory('Graph Neural Networks');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
          topicsRepositoryProvider.overrideWithValue(fakeTopics),
        ],
        child: const MaterialApp(
          home: SearchScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify recent searches section appears
    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(find.text('Graph Neural Networks'), findsOneWidget);

    // Tap the recent search chip
    await tester.tap(find.text('Graph Neural Networks'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeRepo.lastFilters?.query, 'Graph Neural Networks');
    expect(find.text('Found Paper for Graph Neural Networks'), findsOneWidget);
  });
}
