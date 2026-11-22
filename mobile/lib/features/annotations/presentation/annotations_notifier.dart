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

class UserAnnotationsState {
  const UserAnnotationsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.selectedColor,
    this.searchQuery = '',
  });

  final List<UserAnnotation> items;
  final bool isLoading;
  final String? error;
  final String? selectedColor;
  final String searchQuery;

  UserAnnotationsState copyWith({
    List<UserAnnotation>? items,
    bool? isLoading,
    String? error,
    String? selectedColor,
    bool clearSelectedColor = false,
    String? searchQuery,
  }) {
    return UserAnnotationsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedColor: clearSelectedColor ? null : (selectedColor ?? this.selectedColor),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class UserAnnotationsNotifier extends StateNotifier<UserAnnotationsState> {
  UserAnnotationsNotifier(this._repo) : super(const UserAnnotationsState()) {
    load();
  }

  final AnnotationRepository _repo;

  Future<void> load({String? color, String? query}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final activeColor = color != null ? (color.isEmpty ? null : color) : state.selectedColor;
      final activeQuery = query ?? (state.searchQuery.isNotEmpty ? state.searchQuery : null);
      final items = await _repo.listUserAnnotations(
        color: activeColor,
        query: activeQuery,
      );
      state = state.copyWith(
        items: items,
        isLoading: false,
        selectedColor: activeColor,
        clearSelectedColor: activeColor == null,
        searchQuery: activeQuery ?? '',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setColorFilter(String? color) {
    if (color == null || color.isEmpty || state.selectedColor == color) {
      state = state.copyWith(clearSelectedColor: true);
      load(color: '');
    } else {
      state = state.copyWith(selectedColor: color);
      load(color: color);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    load(query: query);
  }

  Future<void> deleteAnnotation(String id, String paperId) async {
    await _repo.deleteAnnotation(id: id, paperId: paperId);
    final updated = state.items.where((a) => a.id != id).toList();
    state = state.copyWith(items: updated);
  }

  Future<void> refresh() async {
    await load(
      color: state.selectedColor,
      query: state.searchQuery.isNotEmpty ? state.searchQuery : null,
    );
  }
}

final userAnnotationsProvider =
    StateNotifierProvider<UserAnnotationsNotifier, UserAnnotationsState>((ref) {
  final repo = ref.watch(annotationRepositoryProvider);
  return UserAnnotationsNotifier(repo);
});
