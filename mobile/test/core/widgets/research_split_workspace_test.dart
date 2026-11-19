import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/core/widgets/research_split_workspace.dart';
import 'package:athena/features/ai/domain/ai_models.dart';
import 'package:athena/features/ai/domain/ai_repository.dart';
import 'package:athena/features/annotations/domain/annotation.dart';
import 'package:athena/features/annotations/domain/annotation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAiRepository implements AiRepository {
  @override
  Future<String> createSession(String paperId) async => 'session-123';

  @override
  Future<String> createCollectionSession(String collectionId) async => 'session-col';

  @override
  Future<List<ChatMessage>> messages(String sessionId) async => const [];

  @override
  Stream<ChatStreamEvent> ask(String sessionId, String content) => const Stream.empty();

  @override
  Future<PaperSummaryAI> summarize(String paperId, ExplanationLevel level) async =>
      throw UnimplementedError();
}

class _FakeAnnotationRepository implements AnnotationRepository {
  @override
  Future<List<Annotation>> listAnnotations(String paperId) async => [
        Annotation(
          id: 'ann-1',
          userId: 'user-1',
          paperId: paperId,
          pageNumber: 2,
          sectionIndex: 0,
          selectedText: 'Crucial empirical finding',
          note: 'Notice the sample size',
          color: AnnotationColor.coral,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

  @override
  Future<Annotation> createAnnotation(CreateAnnotationParams params) async =>
      throw UnimplementedError();

  @override
  Future<Annotation> updateAnnotation(UpdateAnnotationParams params) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAnnotation({required String id, required String paperId}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load(force: true);
  });

  Widget createTestApp({
    required Size screenSize,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        aiRepositoryProvider.overrideWithValue(_FakeAiRepository()),
        annotationRepositoryProvider.overrideWithValue(_FakeAnnotationRepository()),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: child,
        ),
      ),
    );
  }

  group('ResearchSplitWorkspace', () {
    testWidgets('renders single pane when screen width is under 1024px',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          screenSize: const Size(800, 600),
          child: const ResearchSplitWorkspace(
            paperId: 'paper-1',
            paperTitle: 'Attention Is All You Need',
            mainPane: Center(child: Text('Main Document Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Main Document Content'), findsOneWidget);
      // Sidebar should not be rendered
      expect(find.text('AI Assistant'), findsNothing);
      expect(find.text('Grounded Research Assistant'), findsNothing);
    });

    testWidgets(
        'renders two-pane split workspace when screen width is >= 1024px',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          screenSize: const Size(1280, 800),
          child: const ResearchSplitWorkspace(
            paperId: 'paper-1',
            paperTitle: 'Attention Is All You Need',
            mainPane: Center(child: Text('Main Document Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Left pane
      expect(find.text('Main Document Content'), findsOneWidget);

      // Right pane AI Assistant tab
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('Grounded Research Assistant'), findsOneWidget);
      expect(find.text('Ask AI grounded on this paper...'), findsOneWidget);

      // Switch to Notes & Highlights tab
      await tester.tap(find.textContaining('Notes & Highlights'));
      await tester.pumpAndSettle();

      // Notes tab content
      expect(find.textContaining('Crucial empirical finding'), findsOneWidget);
      expect(find.text('Notice the sample size'), findsOneWidget);
      expect(find.text('Ask AI about this'), findsOneWidget);
    });

    testWidgets('allows collapsing and expanding the productivity sidebar',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          screenSize: const Size(1280, 800),
          child: const ResearchSplitWorkspace(
            paperId: 'paper-1',
            paperTitle: 'Attention Is All You Need',
            mainPane: Center(child: Text('Main Document Content')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Assistant'), findsOneWidget);

      // Tap collapse chevron
      await tester.tap(find.byTooltip('Collapse sidebar'));
      await tester.pumpAndSettle();

      // Sidebar collapses into slim rail
      expect(find.text('AI Assistant'), findsNothing);
      expect(find.byTooltip('Expand Productivity Sidebar'), findsOneWidget);

      // Tap expand button
      await tester.tap(find.byTooltip('Expand Productivity Sidebar'));
      await tester.pumpAndSettle();

      // Sidebar is restored
      expect(find.text('AI Assistant'), findsOneWidget);
    });
  });
}
