import 'package:athena/core/di.dart';
import 'package:athena/features/collections/domain/collection.dart';
import 'package:athena/features/collections/domain/collection_repository.dart';
import 'package:athena/features/collections/presentation/collections_notifier.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCollectionRepository implements CollectionRepository {
  List<Collection> collections = [
    Collection(
      id: 'c1',
      userId: 'u1',
      name: 'Diffusion Models',
      description: 'Generative image and audio papers',
      color: '#6366F1',
      isPublic: true,
      paperCount: 2,
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),
  ];

  Map<String, List<CollectionPaper>> papers = {
    'c1': [
      CollectionPaper(
        collectionId: 'c1',
        paperId: 'p1',
        paper: const PaperSummary(
          id: 'p1',
          title: 'DDPM: Denoising Diffusion Probabilistic Models',
          abstract: 'Generative modeling using diffusion',
          publishedOn: null,
          year: 2020,
          venueName: 'NeurIPS',
          publicationType: 'conference_paper',
          oaStatus: 'gold',
          isOpenAccess: true,
          citedByCount: 12000,
        ),
        note: 'Seminal DDPM paper',
        position: 0,
        addedAt: DateTime.utc(2026, 11, 1),
      ),
    ],
  };

  @override
  Future<List<Collection>> listCollections() async => List.of(collections);

  @override
  Future<(Collection, List<CollectionPaper>)> getCollection(String id) async {
    final col = collections.firstWhere((c) => c.id == id);
    return (col, papers[id] ?? []);
  }

  @override
  Future<Collection> createCollection({
    required String name,
    String description = '',
    String color = '#6366F1',
    bool isPublic = false,
  }) async {
    final col = Collection(
      id: 'c_${collections.length + 1}',
      userId: 'u1',
      name: name,
      description: description,
      color: color,
      isPublic: isPublic,
      paperCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    collections.insert(0, col);
    papers[col.id] = [];
    return col;
  }

  @override
  Future<Collection> updateCollection(
    String id, {
    String? name,
    String? description,
    String? color,
    bool? isPublic,
  }) async {
    final idx = collections.indexWhere((c) => c.id == id);
    final current = collections[idx];
    final updated = current.copyWith(
      name: name ?? current.name,
      description: description ?? current.description,
      color: color ?? current.color,
      isPublic: isPublic ?? current.isPublic,
      updatedAt: DateTime.now(),
    );
    collections[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteCollection(String id) async {
    collections.removeWhere((c) => c.id != id);
    papers.remove(id);
  }

  @override
  Future<void> addPaper(String collectionId, String paperId, {String note = ''}) async {
    final idx = collections.indexWhere((c) => c.id == collectionId);
    if (idx != -1) {
      collections[idx] = collections[idx].copyWith(paperCount: collections[idx].paperCount + 1);
    }
  }

  @override
  Future<void> removePaper(String collectionId, String paperId) async {
    final list = papers[collectionId] ?? [];
    list.removeWhere((p) => p.paperId == paperId);
    final idx = collections.indexWhere((c) => c.id == collectionId);
    if (idx != -1) {
      collections[idx] = collections[idx].copyWith(paperCount: list.length);
    }
  }

  @override
  Future<String> exportCollection(String collectionId, {String format = 'bibtex'}) async {
    return '@article{ddpm2020, title={DDPM}}';
  }

  @override
  Future<List<PaperMembership>> getPaperMemberships(String paperId) async {
    return collections.map((c) {
      final contains = (papers[c.id] ?? []).any((p) => p.paperId == paperId);
      return PaperMembership(
        collectionId: c.id,
        collectionName: c.name,
        color: c.color,
        containsPaper: contains,
      );
    }).toList();
  }
}

void main() {
  test('collections notifier loads collections and performs lifecycle operations', () async {
    final fakeRepo = FakeCollectionRepository();
    final container = ProviderContainer(
      overrides: [
        collectionRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(collectionsProvider.notifier);
    await notifier.load();

    final state = container.read(collectionsProvider);
    expect(state.hasValue, isTrue);
    expect(state.value!.length, 1);
    expect(state.value!.first.name, 'Diffusion Models');

    // Create Collection
    final created = await notifier.createCollection(
      name: 'Transformers',
      description: 'Attention mechanisms',
      color: '#10B981',
      isPublic: true,
    );
    expect(created.name, 'Transformers');
    expect(container.read(collectionsProvider).value!.length, 2);

    // Update Collection
    final updated = await notifier.updateCollection(
      created.id,
      name: 'Transformers & Large Language Models',
    );
    expect(updated.name, 'Transformers & Large Language Models');
    expect(
      container.read(collectionsProvider).value!.first.name,
      'Transformers & Large Language Models',
    );

    // Add Paper
    await notifier.addPaper(created.id, 'p99');
    expect(
      container.read(collectionsProvider).value!.first.paperCount,
      1,
    );

    // Remove Paper
    await notifier.removePaper(created.id, 'p99');
    expect(
      container.read(collectionsProvider).value!.first.paperCount,
      0,
    );
  });

  test('collection detail notifier loads papers, unlinks paper, and exports citations', () async {
    final fakeRepo = FakeCollectionRepository();
    final container = ProviderContainer(
      overrides: [
        collectionRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(collectionDetailProvider('c1').notifier);
    await notifier.load();

    final state = container.read(collectionDetailProvider('c1'));
    expect(state.hasValue, isTrue);
    expect(state.value!.collection.name, 'Diffusion Models');
    expect(state.value!.papers.length, 1);
    expect(state.value!.papers.first.paper.title, 'DDPM: Denoising Diffusion Probabilistic Models');

    // Export citations
    final bibtex = await notifier.exportCitations(format: 'bibtex');
    expect(bibtex, contains('@article{ddpm2020'));

    // Remove paper
    await notifier.removePaper('p1');
    final afterRemove = container.read(collectionDetailProvider('c1'));
    expect(afterRemove.value!.papers, isEmpty);
    expect(afterRemove.value!.collection.paperCount, 0);
  });
}
