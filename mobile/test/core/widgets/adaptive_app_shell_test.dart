import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/core/router/app_router.dart';
import 'package:athena/core/widgets/adaptive_app_shell.dart';
import 'package:athena/features/feed/domain/feed.dart';
import 'package:athena/features/feed/domain/feed_repository.dart';
import 'package:athena/features/papers/domain/article_content.dart';
import 'package:athena/features/papers/domain/audio_playback.dart';
import 'package:athena/features/papers/domain/citation_graph.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/papers/domain/paper_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeFeedRepo implements FeedRepository {
  @override
  Future<FeedPage> load({
    required FeedSection section,
    List<String> topics = const [],
    String? cursor,
    int limit = 20,
  }) async {
    return const FeedPage(items: [], nextCursor: null);
  }
}

class _FakePaperRepo implements PaperRepository {
  @override
  Future<PaperDetail> getById(String id) => throw UnimplementedError();

  @override
  Future<ArticleContent> getArticleContent(String id) => throw UnimplementedError();

  @override
  Future<String> exportCitation(String id, String format) => throw UnimplementedError();

  @override
  Future<List<PaperSummary>> getCitations(String id, {String direction = 'in', int limit = 20}) =>
      throw UnimplementedError();

  @override
  Future<List<PaperSummary>> getRelated(String id, {int limit = 10}) =>
      throw UnimplementedError();

  @override
  Future<CitationGraph> getCitationGraph(String id, {int depth = 1, int limit = 25}) =>
      throw UnimplementedError();

  @override
  Future<AudioTrack> synthesizeAudio(
    String id, {
    String voice = 'Alloy',
    String length = 'standard',
    String focus = 'general',
  }) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'athena.onboarding.complete': true});
    await UserPreferences.instance.load();
  });

  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(_FakeFeedRepo()),
        paperRepositoryProvider.overrideWithValue(_FakePaperRepo()),
      ],
      child: MaterialApp.router(routerConfig: buildAppRouter()),
    );
  }

  testWidgets('renders mobile NavigationBar when screen width is under breakpoint', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AdaptiveAppShell), findsOneWidget);
  });

  testWidgets('renders wide NavigationRail when screen width is at or above breakpoint', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AdaptiveAppShell), findsOneWidget);
    expect(find.text('ATHENA'), findsWidgets);
  });
}
