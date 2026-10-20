import 'package:athena/core/di.dart';
import 'package:athena/features/history/domain/history_repository.dart';
import 'package:athena/features/history/domain/reading_history.dart';
import 'package:athena/features/history/presentation/history_notifier.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHistoryRepository implements HistoryRepository {
  List<HistoryEntry> items = [];
  Map<String, double> recorded = {};

  @override
  Future<({List<HistoryEntry> items, String nextCursor})> listHistory({String? cursor, int limit = 20}) async {
    return (items: items, nextCursor: '');
  }

  @override
  Future<ReadingProgress> getProgress(String paperId) async {
    final pct = recorded[paperId] ?? 0.0;
    return ReadingProgress(
      paperId: paperId,
      progressPercent: pct,
      completed: pct >= 95.0,
      lastReadAt: DateTime.now(),
    );
  }

  @override
  Future<ReadingProgress> recordProgress({required String paperId, required double progressPercent}) async {
    recorded[paperId] = progressPercent;
    return ReadingProgress(
      paperId: paperId,
      progressPercent: progressPercent,
      completed: progressPercent >= 95.0,
      lastReadAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearHistory() async {
    items.clear();
    recorded.clear();
  }
}

void main() {
  test('history notifier loads initial history from repository', () async {
    final fake = FakeHistoryRepository();
    fake.items = [
      HistoryEntry(
        paper: const PaperSummary(
          id: 'p1',
          title: 'Quantum Advantage',
          publishedOn: null,
          year: 2026,
          venueName: 'Nature',
          publicationType: 'article',
          oaStatus: 'gold',
          isOpenAccess: true,
          citedByCount: 42,
        ),
        progressPercent: 75.0,
        completed: false,
        lastReadAt: DateTime.utc(2026, 10, 20),
      ),
    ];

    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(historyNotifierProvider.notifier);
    await notifier.loadInitial();
    final state = container.read(historyNotifierProvider);

    expect(state.isLoading, isFalse);
    expect(state.items.length, 1);
    expect(state.items.first.paper.id, 'p1');
    expect(state.items.first.progressPercent, 75.0);
  });

  test('history notifier records progress and clears history', () async {
    final fake = FakeHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(historyNotifierProvider.notifier);
    await notifier.recordProgress('p1', 80.0);
    expect(fake.recorded['p1'], 80.0);

    await notifier.clearHistory();
    expect(container.read(historyNotifierProvider).items, isEmpty);
  });
}
