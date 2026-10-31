import 'package:athena/core/di.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/search/domain/search.dart';
import 'package:athena/features/search/domain/search_repository.dart';
import 'package:athena/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    );
  }
}

void main() {
  testWidgets('SearchScreen accepts initialQuery and auto-submits', (tester) async {
    final fakeRepo = _FakeSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'transformers'),
        ),
      ),
    );

    // Initial pump & settle
    await tester.pumpAndSettle();

    expect(find.text('transformers'), findsOneWidget);
    expect(find.text('Found Paper for transformers'), findsOneWidget);
    expect(fakeRepo.lastFilters?.query, 'transformers');
    expect(fakeRepo.lastFilters?.isLive, false);
  });

  testWidgets('SearchScreen toggles between Corpus and Live Web', (tester) async {
    final fakeRepo = _FakeSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'quantum'),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(fakeRepo.lastFilters?.isLive, false);

    // Tap 'Live Web' chip
    await tester.tap(find.text('Live Web'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastFilters?.isLive, true);
  });

  testWidgets('SearchScreen shows Web Search prompt on empty corpus', (tester) async {
    final fakeRepo = _FakeSearchRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: SearchScreen(initialQuery: 'empty-corpus'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Search Web'), findsOneWidget);

    // Tap the 'Search Web' fallback button
    await tester.tap(find.text('Search Web'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastFilters?.isLive, true);
  });
}
