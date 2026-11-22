import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/saved_papers.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/papers/domain/article_content.dart';
import 'package:athena/features/papers/domain/audio_playback.dart';
import 'package:athena/features/papers/domain/citation_graph.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/papers/domain/paper_repository.dart';
import 'package:athena/features/papers/presentation/paper_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePaperRepository implements PaperRepository {
  _FakePaperRepository(this.detail);

  final PaperDetail detail;

  @override
  Future<PaperDetail> getById(String id) async => detail;

  @override
  Future<ArticleContent> getArticleContent(String id) async => throw UnimplementedError();

  @override
  Future<String> exportCitation(String id, String format) async => throw UnimplementedError();

  @override
  Future<List<PaperSummary>> getCitations(String id, {String direction = 'in', int limit = 20}) async => [];

  @override
  Future<List<PaperSummary>> getRelated(String id, {int limit = 10}) async => [];

  @override
  Future<CitationGraph> getCitationGraph(String id, {int depth = 1, int limit = 25}) async =>
      CitationGraph(rootId: id, nodes: const [], edges: const []);

  @override
  Future<AudioTrack> synthesizeAudio(
    String id, {
    String voice = 'Alloy',
    String length = 'standard',
    String focus = 'general',
  }) async =>
      throw UnimplementedError();

  @override
  Future<AuthorDetail> getAuthorById(String id) async => throw UnimplementedError();

  @override
  Future<AuthorWorks> getAuthorPapers(String id, {String sort = 'citations', int limit = 20, int offset = 0}) async =>
      const AuthorWorks(items: [], total: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load();
    await SavedPapers.prime();
  });

  const testPaper = PaperDetail(
    summary: PaperSummary(
      id: 'paper-abc',
      title: 'Attention Is All You Need',
      abstract:
          'The dominant sequence transduction models are based on complex recurrent or convolutional neural networks.',
      publishedOn: null,
      year: 2017,
      venueName: 'NeurIPS',
      publicationType: 'conference_paper',
      oaStatus: 'gold',
      isOpenAccess: true,
      citedByCount: 95000,
    ),
    language: 'en',
    license: 'cc-by',
    bestOaUrl: 'https://arxiv.org/pdf/1706.03762',
    doi: '10.48550/arXiv.1706.03762',
    arxivId: '1706.03762',
    authors: [
      AuthorLine(id: 'a1', name: 'Ashish Vaswani'),
      AuthorLine(id: 'a2', name: 'Noam Shazeer'),
      AuthorLine(id: 'a3', name: 'Niki Parmar'),
      AuthorLine(id: 'a4', name: 'Jakob Uszkoreit'),
    ],
    topics: [TopicLine(slug: 'transformers', name: 'Transformers', score: 0.95, isPrimary: true)],
    versions: [],
    referenceCount: 38,
    sources: ['arxiv'],
  );

  testWidgets(
      'PaperDetailScreen renders Share action button and copies formatted details to clipboard',
      (tester) async {
    final fakeRepo = _FakePaperRepository(testPaper);

    String? clipboardData;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          clipboardData = (methodCall.arguments as Map)['text'] as String?;
          return null;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paperRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: PaperDetailScreen(id: 'paper-abc'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Attention Is All You Need'), findsOneWidget);

    final shareButton = find.byTooltip('Share Paper');
    expect(shareButton, findsOneWidget);

    await tester.tap(shareButton);
    await tester.pump();

    expect(clipboardData, isNotNull);
    expect(clipboardData, contains('Attention Is All You Need'));
    expect(clipboardData, contains('Ashish Vaswani, Noam Shazeer, Niki Parmar et al.'));
    expect(clipboardData, contains('NeurIPS · 2017'));
    expect(clipboardData, contains('https://doi.org/10.48550/arXiv.1706.03762'));

    expect(find.text('Paper details & link copied to clipboard'), findsOneWidget);
  });
}
