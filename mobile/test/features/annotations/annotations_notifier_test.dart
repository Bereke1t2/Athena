import 'package:athena/core/di.dart';
import 'package:athena/features/annotations/domain/annotation.dart';
import 'package:athena/features/annotations/domain/annotation_repository.dart';
import 'package:athena/features/annotations/presentation/annotations_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnnotationRepository implements AnnotationRepository {
  final Map<String, List<Annotation>> _storage = {};
  final List<UserAnnotation> userStorage = [];

  @override
  Future<List<Annotation>> listAnnotations(String paperId) async {
    return List.of(_storage[paperId] ?? []);
  }

  @override
  Future<Annotation> createAnnotation(CreateAnnotationParams params) async {
    final annotation = Annotation(
      id: 'annot-${DateTime.now().microsecondsSinceEpoch}',
      userId: 'test-user-1',
      paperId: params.paperId,
      pageNumber: params.pageNumber,
      sectionIndex: params.sectionIndex,
      selectedText: params.selectedText,
      note: params.note,
      color: params.color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final current = _storage[params.paperId] ?? [];
    _storage[params.paperId] = [annotation, ...current];
    return annotation;
  }

  @override
  Future<Annotation> updateAnnotation(UpdateAnnotationParams params) async {
    final list = _storage[params.paperId] ?? [];
    final idx = list.indexWhere((a) => a.id == params.id);
    if (idx == -1) throw Exception('Not found');

    final existing = list[idx];
    final updated = existing.copyWith(
      note: params.note ?? existing.note,
      color: params.color ?? existing.color,
      updatedAt: DateTime.now(),
    );
    list[idx] = updated;
    _storage[params.paperId] = list;
    return updated;
  }

  @override
  Future<void> deleteAnnotation({required String id, required String paperId}) async {
    final list = _storage[paperId] ?? [];
    list.removeWhere((a) => a.id == id);
    _storage[paperId] = list;
    userStorage.removeWhere((a) => a.id == id);
  }

  @override
  Future<List<UserAnnotation>> listUserAnnotations({
    String? color,
    String? query,
    int limit = 50,
  }) async {
    var result = List.of(userStorage);
    if (color != null && color.isNotEmpty) {
      result = result.where((a) => a.color.code == color).toList();
    }
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      result = result.where((a) =>
          a.selectedText.toLowerCase().contains(q) ||
          a.note.toLowerCase().contains(q) ||
          a.paperTitle.toLowerCase().contains(q)).toList();
    }
    return result;
  }
}

void main() {
  group('Annotation and AnnotationColor Domain', () {
    test('AnnotationColor resolves codes correctly and falls back to yellow', () {
      expect(AnnotationColor.fromCode('yellow'), equals(AnnotationColor.yellow));
      expect(AnnotationColor.fromCode('coral'), equals(AnnotationColor.coral));
      expect(AnnotationColor.fromCode('emerald'), equals(AnnotationColor.emerald));
      expect(AnnotationColor.fromCode('cyan'), equals(AnnotationColor.cyan));
      expect(AnnotationColor.fromCode('purple'), equals(AnnotationColor.purple));
      expect(AnnotationColor.fromCode('unknown'), equals(AnnotationColor.yellow));
      expect(AnnotationColor.fromCode(null), equals(AnnotationColor.yellow));
    });

    test('Annotation JSON serialization and deserialization roundtrip', () {
      final now = DateTime.utc(2026, 11, 19, 10, 0, 0);
      final annot = Annotation(
        id: 'a1',
        userId: 'u1',
        paperId: 'p1',
        pageNumber: 4,
        sectionIndex: 2,
        selectedText: 'Residual connections facilitate gradient flow.',
        note: 'Key insight for training deep residual networks.',
        color: AnnotationColor.coral,
        createdAt: now,
        updatedAt: now,
      );

      final json = annot.toJson();
      expect(json['id'], equals('a1'));
      expect(json['color'], equals('coral'));
      expect(json['page_number'], equals(4));

      final restored = Annotation.fromJson(json);
      expect(restored.id, equals('a1'));
      expect(restored.color, equals(AnnotationColor.coral));
      expect(restored.selectedText, equals(annot.selectedText));
      expect(restored.note, equals(annot.note));
    });

    test('Annotation copyWith updates selected fields', () {
      final annot = Annotation(
        id: 'a1',
        userId: 'u1',
        paperId: 'p1',
        pageNumber: 1,
        sectionIndex: 0,
        selectedText: 'Initial text',
        note: 'Initial note',
        color: AnnotationColor.yellow,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = annot.copyWith(
        note: 'Revised margin note',
        color: AnnotationColor.emerald,
      );

      expect(updated.id, equals('a1'));
      expect(updated.note, equals('Revised margin note'));
      expect(updated.color, equals(AnnotationColor.emerald));
      expect(updated.selectedText, equals('Initial text'));
    });
  });

  group('PaperAnnotationsNotifier Lifecycle', () {
    late FakeAnnotationRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAnnotationRepository();
      container = ProviderContainer(
        overrides: [
          annotationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('loads empty list on initialization', () async {
      container.read(paperAnnotationsProvider('paper-123').notifier);
      await pumpEventQueue();

      final state = container.read(paperAnnotationsProvider('paper-123'));
      expect(state.value, isEmpty);
    });

    test('creates highlight and margin note, then updates and deletes it', () async {
      final notifier = container.read(paperAnnotationsProvider('paper-123').notifier);
      await pumpEventQueue();

      // 1. Create annotation
      final created = await notifier.createAnnotation(
        pageNumber: 2,
        sectionIndex: 1,
        selectedText: 'Self-attention mechanism computes pairwise representations.',
        note: 'Crucial for Transformer scalability',
        color: AnnotationColor.coral,
      );

      expect(created.paperId, equals('paper-123'));
      expect(created.pageNumber, equals(2));
      expect(created.color, equals(AnnotationColor.coral));
      expect(created.note, equals('Crucial for Transformer scalability'));

      var state = container.read(paperAnnotationsProvider('paper-123'));
      expect(state.value?.length, equals(1));
      expect(state.value?.first.id, equals(created.id));

      // 2. Update annotation note and color
      final updated = await notifier.updateAnnotation(
        id: created.id,
        note: 'Refined note: quadratic complexity in sequence length',
        color: AnnotationColor.purple,
      );

      expect(updated.note, equals('Refined note: quadratic complexity in sequence length'));
      expect(updated.color, equals(AnnotationColor.purple));

      state = container.read(paperAnnotationsProvider('paper-123'));
      expect(state.value?.first.color, equals(AnnotationColor.purple));
      expect(state.value?.first.note, equals('Refined note: quadratic complexity in sequence length'));

      // 3. Delete annotation
      await notifier.deleteAnnotation(created.id);

      state = container.read(paperAnnotationsProvider('paper-123'));
      expect(state.value, isEmpty);
    });
  });

  group('UserAnnotation & UserAnnotationsNotifier', () {
    late FakeAnnotationRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeAnnotationRepository();
      fakeRepo.userStorage.addAll([
        UserAnnotation(
          id: 'ua-1',
          userId: 'u1',
          paperId: 'p1',
          paperTitle: 'Attention Is All You Need',
          paperYear: 2017,
          paperVenue: 'NeurIPS',
          pageNumber: 3,
          sectionIndex: 1,
          selectedText: 'The dominant sequence models are based on complex recurrent networks.',
          note: 'Baseline comparison',
          color: AnnotationColor.yellow,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        UserAnnotation(
          id: 'ua-2',
          userId: 'u1',
          paperId: 'p2',
          paperTitle: 'Deep Residual Learning for Image Recognition',
          paperYear: 2016,
          paperVenue: 'CVPR',
          pageNumber: 4,
          sectionIndex: 2,
          selectedText: 'Residual connections solve degradation problems in very deep networks.',
          note: 'Key insight for ResNets',
          color: AnnotationColor.coral,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);

      container = ProviderContainer(
        overrides: [
          annotationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('UserAnnotation JSON roundtrip preserves metadata', () {
      final now = DateTime.utc(2026, 11, 22, 10, 0, 0);
      final annot = UserAnnotation(
        id: 'ua-100',
        userId: 'u100',
        paperId: 'p100',
        paperTitle: 'Diffusion Models Beat GANs',
        paperYear: 2021,
        paperVenue: 'NeurIPS',
        paperDoi: '10.1234/test',
        pageNumber: 2,
        sectionIndex: 0,
        selectedText: 'Classifier guidance enhances image synthesis quality.',
        note: 'Important guidance technique',
        color: AnnotationColor.emerald,
        createdAt: now,
        updatedAt: now,
      );

      final json = annot.toJson();
      expect(json['id'], equals('ua-100'));
      expect(json['paper_title'], equals('Diffusion Models Beat GANs'));
      expect(json['paper_year'], equals(2021));
      expect(json['color'], equals('emerald'));

      final restored = UserAnnotation.fromJson(json);
      expect(restored.id, equals('ua-100'));
      expect(restored.paperTitle, equals('Diffusion Models Beat GANs'));
      expect(restored.paperVenue, equals('NeurIPS'));
      expect(restored.paperDoi, equals('10.1234/test'));
      expect(restored.color, equals(AnnotationColor.emerald));
    });

    test('UserAnnotationsNotifier loads items and applies color and text filters', () async {
      final notifier = container.read(userAnnotationsProvider.notifier);
      await pumpEventQueue();

      var state = container.read(userAnnotationsProvider);
      expect(state.items.length, equals(2));

      // Filter by color 'coral'
      notifier.setColorFilter('coral');
      await pumpEventQueue();

      state = container.read(userAnnotationsProvider);
      expect(state.items.length, equals(1));
      expect(state.items.first.paperTitle, contains('Deep Residual Learning'));
      expect(state.selectedColor, equals('coral'));

      // Clear color filter
      notifier.setColorFilter(null);
      await pumpEventQueue();
      state = container.read(userAnnotationsProvider);
      expect(state.items.length, equals(2));

      // Filter by search query 'recurrent'
      notifier.setSearchQuery('recurrent');
      await pumpEventQueue();
      state = container.read(userAnnotationsProvider);
      expect(state.items.length, equals(1));
      expect(state.items.first.paperTitle, contains('Attention Is All You Need'));

      // Delete annotation
      await notifier.deleteAnnotation('ua-1', 'p1');
      state = container.read(userAnnotationsProvider);
      expect(state.items, isEmpty);
    });
  });
}
