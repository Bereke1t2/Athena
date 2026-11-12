import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../domain/collection.dart';
import '../domain/collection_repository.dart';

class CollectionsNotifier extends StateNotifier<AsyncValue<List<Collection>>> {
  CollectionsNotifier(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final CollectionRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final items = await _repo.listCollections();
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Collection> createCollection({
    required String name,
    String description = '',
    String color = '#6366F1',
    bool isPublic = false,
  }) async {
    final created = await _repo.createCollection(
      name: name,
      description: description,
      color: color,
      isPublic: isPublic,
    );

    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([created, ...current]);
    return created;
  }

  Future<Collection> updateCollection(
    String id, {
    String? name,
    String? description,
    String? color,
    bool? isPublic,
  }) async {
    final updated = await _repo.updateCollection(
      id,
      name: name,
      description: description,
      color: color,
      isPublic: isPublic,
    );

    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((c) => c.id == id ? updated : c).toList(),
    );
    return updated;
  }

  Future<void> deleteCollection(String id) async {
    await _repo.deleteCollection(id);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((c) => c.id != id).toList(),
    );
  }

  Future<void> addPaper(String collectionId, String paperId, {String note = ''}) async {
    await _repo.addPaper(collectionId, paperId, note: note);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((c) {
        if (c.id == collectionId) {
          return c.copyWith(paperCount: c.paperCount + 1);
        }
        return c;
      }).toList(),
    );
  }

  Future<void> removePaper(String collectionId, String paperId) async {
    await _repo.removePaper(collectionId, paperId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((c) {
        if (c.id == collectionId) {
          return c.copyWith(paperCount: (c.paperCount > 0) ? c.paperCount - 1 : 0);
        }
        return c;
      }).toList(),
    );
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionsNotifier, AsyncValue<List<Collection>>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return CollectionsNotifier(repo);
});

class CollectionDetailNotifier
    extends StateNotifier<AsyncValue<({Collection collection, List<CollectionPaper> papers})>> {
  CollectionDetailNotifier(this._repo, this._collectionId)
      : super(const AsyncValue.loading()) {
    load();
  }

  final CollectionRepository _repo;
  final String _collectionId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final (col, papers) = await _repo.getCollection(_collectionId);
      state = AsyncValue.data((collection: col, papers: papers));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> removePaper(String paperId) async {
    await _repo.removePaper(_collectionId, paperId);
    final current = state.valueOrNull;
    if (current != null) {
      final updatedPapers = current.papers.where((p) => p.paperId != paperId).toList();
      final updatedCol = current.collection.copyWith(paperCount: updatedPapers.length);
      state = AsyncValue.data((collection: updatedCol, papers: updatedPapers));
    }
  }

  Future<String> exportCitations({String format = 'bibtex'}) async {
    return _repo.exportCollection(_collectionId, format: format);
  }
}

final collectionDetailProvider = StateNotifierProvider.autoDispose.family<
    CollectionDetailNotifier,
    AsyncValue<({Collection collection, List<CollectionPaper> papers})>,
    String>((ref, id) {
  final repo = ref.watch(collectionRepositoryProvider);
  return CollectionDetailNotifier(repo, id);
});

final paperMembershipsProvider =
    FutureProvider.autoDispose.family<List<PaperMembership>, String>((ref, paperId) async {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo.getPaperMemberships(paperId);
});
