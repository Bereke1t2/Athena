import 'package:athena/core/di.dart';
import 'package:athena/features/annotations/domain/annotation.dart';
import 'package:athena/features/annotations/domain/annotation_repository.dart';
import 'package:athena/features/annotations/presentation/annotations_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnnotationRepository implements AnnotationRepository {
  final Map<String, List<Annotation>> _storage = {};

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
}
