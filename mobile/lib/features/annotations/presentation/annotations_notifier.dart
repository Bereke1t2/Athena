import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../domain/annotation.dart';
import '../domain/annotation_repository.dart';

class PaperAnnotationsNotifier extends StateNotifier<AsyncValue<List<Annotation>>> {
  PaperAnnotationsNotifier(this._repo, this.paperId) : super(const AsyncValue.loading()) {
    load();
  }

  final AnnotationRepository _repo;
  final String paperId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repo.listAnnotations(paperId);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Annotation> createAnnotation({
    int pageNumber = 1,
    int sectionIndex = 0,
    required String selectedText,
    String note = '',
    AnnotationColor color = AnnotationColor.yellow,
  }) async {
    final created = await _repo.createAnnotation(
      CreateAnnotationParams(
        paperId: paperId,
        pageNumber: pageNumber,
        sectionIndex: sectionIndex,
        selectedText: selectedText,
        note: note,
        color: color,
      ),
    );
    final current = (state.valueOrNull ?? []).where((a) => a.id != created.id).toList();
    state = AsyncValue.data([created, ...current]);
    return created;
  }

  Future<Annotation> updateAnnotation({
    required String id,
    String? note,
    AnnotationColor? color,
  }) async {
    final updated = await _repo.updateAnnotation(
      UpdateAnnotationParams(
        id: id,
        paperId: paperId,
        note: note,
        color: color,
      ),
    );
    final current = (state.valueOrNull ?? []).map((a) => a.id == id ? updated : a).toList();
    state = AsyncValue.data(current);
    return updated;
  }

  Future<void> deleteAnnotation(String id) async {
    await _repo.deleteAnnotation(id: id, paperId: paperId);
    final current = (state.valueOrNull ?? []).where((a) => a.id != id).toList();
    state = AsyncValue.data(current);
  }
}

final paperAnnotationsProvider = StateNotifierProvider.family<
    PaperAnnotationsNotifier,
    AsyncValue<List<Annotation>>,
    String>((ref, paperId) {
  final repo = ref.watch(annotationRepositoryProvider);
  return PaperAnnotationsNotifier(repo, paperId);
});
