import 'package:athena/core/di.dart';
import 'package:athena/features/topics/domain/topic.dart';
import 'package:athena/features/topics/domain/topics_repository.dart';
import 'package:athena/features/topics/presentation/topics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTopicsRepository implements TopicsRepository {
  String? lastQuery;
  String? lastKind;

  final allTopics = const [
    Topic(
      slug: 'neural-networks',
      name: 'Neural Networks',
      kind: 'topic',
      paperCountEstimate: 120,
      parentSlug: 'computer-science',
      parentName: 'Computer Science',
    ),
    Topic(
      slug: 'computer-science',
      name: 'Computer Science',
      kind: 'field',
      paperCountEstimate: 500,
    ),
    Topic(
      slug: 'quantum-computing',
      name: 'Quantum Computing',
      kind: 'topic',
      paperCountEstimate: 45,
      parentSlug: 'physics-and-astronomy',
      parentName: 'Physics and Astronomy',
    ),
  ];

  @override
  Future<TopicPage> list({
    String? kind,
    String? query,
    String? parent,
    String? cursor,
    int limit = 50,
  }) async {
    lastQuery = query;
    lastKind = kind;

    var filtered = allTopics;
    if (kind != null && kind.isNotEmpty) {
      filtered = filtered.where((t) => t.kind == kind).toList();
    }
    if (query != null && query.isNotEmpty) {
      filtered = filtered.where((t) =>
          t.name.toLowerCase().contains(query.toLowerCase()) ||
          t.slug.toLowerCase().contains(query.toLowerCase())).toList();
    }

    return TopicPage(items: filtered, nextCursor: null);
  }

  @override
  Future<Topic> getBySlug(String slug) async {
    return allTopics.firstWhere((t) => t.slug == slug);
  }

  @override
  Future<PaperListPage> listResearch(String slug, {String sort = 'relevance', String? cursor, int limit = 20}) async {
    return const PaperListPage(items: [], nextCursor: null);
  }
}

void main() {
  testWidgets('TopicsScreen displays topics and allows real-time text search', (tester) async {
    final fakeRepo = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topicsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: TopicsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Neural Networks'), findsOneWidget);
    expect(find.text('Computer Science'), findsNWidgets(2)); // Title and parent badge
    expect(find.text('Quantum Computing'), findsOneWidget);

    // Enter search query
    await tester.enterText(find.byType(SearchBar), 'quantum');
    await tester.pumpAndSettle();

    expect(find.text('Quantum Computing'), findsOneWidget);
    expect(find.text('Neural Networks'), findsNothing);
    expect(fakeRepo.lastQuery, 'quantum');
  });

  testWidgets('TopicsScreen filters by kind', (tester) async {
    final fakeRepo = _FakeTopicsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          topicsRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: TopicsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap 'Fields' segment
    await tester.tap(find.text('Fields'));
    await tester.pumpAndSettle();

    expect(find.text('Computer Science'), findsOneWidget);
    expect(find.text('Neural Networks'), findsNothing);
    expect(fakeRepo.lastKind, 'field');
  });
}
