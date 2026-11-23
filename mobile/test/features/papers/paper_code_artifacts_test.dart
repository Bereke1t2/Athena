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

class _FakeArtifactsPaperRepository implements PaperRepository {
  _FakeArtifactsPaperRepository(this.detail);

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

  const baseSummary = PaperSummary(
    id: 'paper-code-123',
    title: 'An Image is Worth 16x16 Words: Transformers for Image Recognition at Scale',
    abstract: 'Vision Transformer (ViT) achieves excellent results compared to CNNs.',
    publishedOn: null,
    year: 2021,
    venueName: 'ICLR',
    publicationType: 'conference_paper',
    oaStatus: 'gold',
    isOpenAccess: true,
    citedByCount: 42000,
    hasCode: true,
    primaryCodeUrl: 'https://github.com/google-research/vision_transformer',
  );

  const paperWithCodeAndData = PaperDetail(
    summary: baseSummary,
    language: 'en',
    license: 'apache-2.0',
    bestOaUrl: 'https://arxiv.org/pdf/2010.11929',
    doi: '',
    arxivId: '2010.11929',
    authors: [
      AuthorLine(id: 'a1', name: 'Alexey Dosovitskiy'),
      AuthorLine(id: 'a2', name: 'Lucas Beyer'),
    ],
    topics: [
      TopicLine(slug: 'computer-vision', name: 'Computer Vision', score: 1.0, isPrimary: true),
    ],
    versions: [],
    referenceCount: 65,
    sources: ['arxiv'],
    codeRepositories: [
      CodeRepository(
        url: 'https://github.com/google-research/vision_transformer',
        platform: 'github',
        owner: 'google-research',
        repoName: 'vision_transformer',
        description: 'Official JAX / Flax implementation of Vision Transformer models',
        isOfficial: true,
        starsCount: 15400,
      ),
    ],
    datasets: [
      DatasetReference(
        url: 'https://huggingface.co/datasets/imagenet-1k',
        platform: 'huggingface',
        name: 'ImageNet-1K',
        description: 'Standard benchmark dataset',
      ),
    ],
  );

  testWidgets('renders Code & Datasets section and quick action button when code exists', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paperRepositoryProvider.overrideWithValue(_FakeArtifactsPaperRepository(paperWithCodeAndData)),
        ],
        child: const MaterialApp(
          home: PaperDetailScreen(id: 'paper-code-123'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('code-artifacts-card')), findsOneWidget);
    expect(find.text('Code & Datasets'), findsOneWidget);
    expect(find.text('google-research/vision_transformer'), findsOneWidget);
    expect(find.text('Official'), findsOneWidget);
    expect(find.text('Open Repo'), findsOneWidget);
    expect(find.text('Clone'), findsOneWidget);
    expect(find.text('ImageNet-1K'), findsOneWidget);
    expect(find.byKey(const Key('quick-view-code-button')), findsOneWidget);
  });

  testWidgets('clicking Clone copies git clone command to clipboard', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        copiedText = (methodCall.arguments as Map<dynamic, dynamic>)['text'] as String?;
      }
      return null;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paperRepositoryProvider.overrideWithValue(_FakeArtifactsPaperRepository(paperWithCodeAndData)),
        ],
        child: const MaterialApp(
          home: PaperDetailScreen(id: 'paper-code-123'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final cloneButton = find.widgetWithText(OutlinedButton, 'Clone');
    expect(cloneButton, findsOneWidget);
    await tester.tap(cloneButton);
    await tester.pump();

    expect(copiedText, 'git clone https://github.com/google-research/vision_transformer.git');
    expect(find.text('Clone command copied to clipboard'), findsOneWidget);
  });

  testWidgets('renders fallback Search GitHub prompt when no code is linked', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const paperNoCode = PaperDetail(
      summary: PaperSummary(
        id: 'paper-nocode-456',
        title: 'A Pure Theory of Abstract Philosophy',
        abstract: 'An abstract discussion.',
        publishedOn: null,
        year: 1990,
        venueName: 'Philosophy Review',
        publicationType: 'journal_article',
        oaStatus: 'closed',
        isOpenAccess: false,
        citedByCount: 15,
      ),
      language: 'en',
      license: '',
      bestOaUrl: '',
      doi: '',
      arxivId: '',
      authors: [],
      topics: [],
      versions: [],
      referenceCount: 10,
      sources: ['crossref'],
      codeRepositories: [],
      datasets: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paperRepositoryProvider.overrideWithValue(_FakeArtifactsPaperRepository(paperNoCode)),
        ],
        child: const MaterialApp(
          home: PaperDetailScreen(id: 'paper-nocode-456'),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('code-artifacts-card')), findsOneWidget);
    expect(find.text('No repository explicitly linked'), findsOneWidget);
    expect(find.text('Search GitHub'), findsOneWidget);
    expect(find.byKey(const Key('quick-view-code-button')), findsNothing);
  });
}
