import 'package:athena/core/di.dart';
import 'package:athena/core/error/failure.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/search/domain/search.dart';
import 'package:athena/features/search/domain/search_repository.dart'
    show SearchRepository;
import 'package:athena/features/search/presentation/search_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSearchRepository implements SearchRepository {
  FakeSearchRepository();

  final List<({SearchFilters filters, String? cursor})> calls = [];

  @override
  Future<SearchPage> search(SearchFilters filters, {String? cursor, int limit = 20}) async {
    calls.add((filters: filters, cursor: cursor));
    // Pages mirror the requested sort to assert filter propagation.
    final firstIds = filters.sort == SearchSort.newest ? ['n3'] : ['a', 'b'];
    if (cursor == null) {
      return _page(firstIds, nextCursor: 'CUR1');
    }
    final ids = filters.sort == SearchSort.newest ? ['n4'] : ['c3'];
    return _page(ids);
  }

  SearchPage _page(List<String> ids, {String? nextCursor, String modeUsed = 'keyword'}) =>
      SearchPage(
        items: [
          for (final id in ids)
            SearchResult(
              score: 0.5,
              paper: PaperSummary(
                id: id,
                title: 'Paper $id',
                publishedOn: DateTime.utc(2026, 2, 1),
                year: 2026,
                venueName: 'V',
                publicationType: 'article',
                oaStatus: 'closed',
                isOpenAccess: false,
                citedByCount: 3,
              ),
            ),
        ],
        nextCursor: nextCursor,
        modeUsed: modeUsed,
        totalEstimate: ids.length,
      );
}

void main() {
  test('submit loads results and reports meta', () async {
    final fake = FakeSearchRepository();
    final container = ProviderContainer(overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);

    await notifier.submit('  protein folding  ');

    final state = container.read(searchNotifierProvider);
    expect(state.submitted, isTrue);
    expect(state.filters.query, 'protein folding');
    expect(state.page.value!.results.map((r) => r.paper.id), ['a', 'b']);
    expect(state.page.value!.cursor, 'CUR1');
    expect(state.page.value!.totalEstimate, 2);

    await notifier.loadMore();
    final after = container.read(searchNotifierProvider).page.value!;
    expect(after.results.map((r) => r.paper.id), ['a', 'b', 'c3']);
    expect(after.cursor, isNull); // second page had no cursor
  });

  test('setSort re-runs the query with new sort', () async {
    final fake = FakeSearchRepository();
    final container = ProviderContainer(overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);

    await notifier.submit('transformers');
    await notifier.setSort(SearchSort.newest);

    final page = container.read(searchNotifierProvider).page.value!;
    expect(page.results.single.paper.id, 'n3');
    expect(fake.calls.last.filters.sort, SearchSort.newest);
  });

  test('empty submit is ignored', () async {
    final fake = FakeSearchRepository();
    final container = ProviderContainer(overrides: [
      searchRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);

    await notifier.submit('   ');
    expect(container.read(searchNotifierProvider).submitted, isFalse);
    expect(fake.calls, isEmpty);
  });

  test('failures land in the error slot', () async {
    final container = ProviderContainer(overrides: [
      searchRepositoryProvider.overrideWith((ref) => _ThrowingRepo()),
    ]);
    addTearDown(container.dispose);
    final notifier = container.read(searchNotifierProvider.notifier);

    await notifier.submit('x');
    expect(container.read(searchNotifierProvider).page, isA<AsyncError>());
  });
}

class _ThrowingRepo implements SearchRepository {
  @override
  Future<SearchPage> search(SearchFilters filters, {String? cursor, int limit = 20}) async {
    throw const NetworkFailure();
  }
}
