import 'package:athena/core/di.dart';
import 'package:athena/features/papers/domain/pdf_repository.dart';
import 'package:athena/features/storage/domain/storage_models.dart';
import 'package:athena/features/storage/domain/storage_repository.dart';
import 'package:athena/features/storage/presentation/storage_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeStorageRepository implements StorageRepository {
  List<CachedPdfInfo> cachedPdfs = [
    CachedPdfInfo(
      paperId: 'p1',
      filePath: '/docs/pdfs/p1.pdf',
      sizeBytes: 2500000, // ~2.4 MB
      modifiedAt: DateTime.utc(2026, 11, 15),
    ),
    CachedPdfInfo(
      paperId: 'p2',
      filePath: '/docs/pdfs/p2.pdf',
      sizeBytes: 1500000, // ~1.4 MB
      modifiedAt: DateTime.utc(2026, 11, 18),
    ),
  ];

  int searchHistoryCount = 5;
  int annotationsCount = 2;

  @override
  Future<StorageBreakdown> getStorageBreakdown() async {
    final pdfBytes = cachedPdfs.fold<int>(0, (acc, p) => acc + p.sizeBytes);
    return StorageBreakdown(
      pdfBytes: pdfBytes,
      pdfCount: cachedPdfs.length,
      searchHistoryCount: searchHistoryCount,
      annotationsCount: annotationsCount,
    );
  }

  @override
  Future<List<CachedPdfInfo>> listCachedPdfs() async => List.of(cachedPdfs);

  @override
  Future<void> deletePdf(String paperId) async {
    cachedPdfs.removeWhere((p) => p.paperId == paperId);
  }

  @override
  Future<void> clearAllPdfs() async {
    cachedPdfs.clear();
  }

  @override
  Future<void> clearSearchHistory() async {
    searchHistoryCount = 0;
  }

  @override
  Future<void> clearAllStorage() async {
    cachedPdfs.clear();
    searchHistoryCount = 0;
  }

  @override
  Future<OfflineFlightBatchResult> downloadFlightPack(
    List<(String paperId, String pdfUrl)> items, {
    void Function(int completed, int total)? onProgress,
  }) async {
    var downloaded = 0;
    var skipped = 0;
    var failed = 0;

    for (var i = 0; i < items.length; i++) {
      final (id, url) = items[i];
      if (cachedPdfs.any((p) => p.paperId == id)) {
        skipped++;
      } else if (url.isNotEmpty) {
        cachedPdfs.add(CachedPdfInfo(
          paperId: id,
          filePath: '/docs/pdfs/$id.pdf',
          sizeBytes: 2000000,
          modifiedAt: DateTime.now(),
        ));
        downloaded++;
      } else {
        failed++;
      }
      onProgress?.call(i + 1, items.length);
    }

    return OfflineFlightBatchResult(
      total: items.length,
      downloaded: downloaded,
      skipped: skipped,
      failed: failed,
    );
  }
}

void main() {
  group('Storage Models & Byte Formatting', () {
    test('formatStorageBytes formats various byte sizes cleanly', () {
      expect(formatStorageBytes(0), equals('0 B'));
      expect(formatStorageBytes(512), equals('512 B'));
      expect(formatStorageBytes(2048), equals('2.0 KB'));
      expect(formatStorageBytes(15728640), equals('15 MB')); // ~15 MB
      expect(formatStorageBytes(1073741824), equals('1.0 GB'));
    });

    test('StorageBreakdown accurately calculates estimated totals', () {
      const breakdown = StorageBreakdown(
        pdfBytes: 4000000,
        pdfCount: 2,
        searchHistoryCount: 5,
        annotationsCount: 2,
      );

      expect(breakdown.pdfBytes, equals(4000000));
      expect(breakdown.pdfCount, equals(2));
      expect(breakdown.formattedPdfSize, equals('3.8 MB'));
      expect(breakdown.totalEstimatedBytes, greaterThan(4000000));
    });
  });

  group('StorageNotifier Lifecycle', () {
    late FakeStorageRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeStorageRepository();
      container = ProviderContainer(
        overrides: [
          storageRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('initializes and loads storage breakdown and cached PDFs', () async {
      container.read(storageNotifierProvider.notifier);
      await pumpEventQueue();

      final state = container.read(storageNotifierProvider);
      expect(state.isLoading, isFalse);
      expect(state.cachedPdfs.length, equals(2));
      expect(state.breakdown.pdfCount, equals(2));
      expect(state.breakdown.pdfBytes, equals(4000000));
    });

    test('deletes individual PDF and updates state', () async {
      final notifier = container.read(storageNotifierProvider.notifier);
      await pumpEventQueue();

      await notifier.deletePdf('p1');

      final state = container.read(storageNotifierProvider);
      expect(state.cachedPdfs.length, equals(1));
      expect(state.cachedPdfs.first.paperId, equals('p2'));
      expect(state.breakdown.pdfCount, equals(1));
      expect(state.message, contains('Removed PDF'));
    });

    test('clears all cached PDFs', () async {
      final notifier = container.read(storageNotifierProvider.notifier);
      await pumpEventQueue();

      await notifier.clearAllPdfs();

      final state = container.read(storageNotifierProvider);
      expect(state.cachedPdfs, isEmpty);
      expect(state.breakdown.pdfCount, equals(0));
      expect(state.breakdown.pdfBytes, equals(0));
    });

    test('downloads flight pack batch and updates progress and state', () async {
      final notifier = container.read(storageNotifierProvider.notifier);
      await pumpEventQueue();

      final result = await notifier.downloadFlightPack([
        ('p1', 'https://arxiv.org/pdf/p1.pdf'), // already cached
        ('p3', 'https://arxiv.org/pdf/p3.pdf'), // new download
        ('p4', ''),                             // invalid/empty
      ]);

      expect(result.total, equals(3));
      expect(result.skipped, equals(1));
      expect(result.downloaded, equals(1));
      expect(result.failed, equals(1));

      final state = container.read(storageNotifierProvider);
      expect(state.cachedPdfs.any((p) => p.paperId == 'p3'), isTrue);
      expect(state.message, contains('Flight Pack Ready'));
    });
  });
}
