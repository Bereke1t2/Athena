import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/core/router/app_router.dart';
import 'package:athena/features/feed/domain/feed.dart';
import 'package:athena/features/feed/domain/feed_repository.dart';
import 'package:athena/features/papers/domain/article_content.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/papers/domain/paper_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoopFeedRepo implements FeedRepository {
  @override
  Future<FeedPage> load({required FeedSection section, List<String> topics = const [], String? cursor, int limit = 20}) async {
    return const FeedPage(items: [], nextCursor: null);
  }
}

class _NoopPaperRepo implements PaperRepository {
  @override
  Future<PaperDetail> getById(String id) => throw UnimplementedError();

  @override
  Future<ArticleContent> getArticleContent(String id) => throw UnimplementedError();
}

void main() {
  setUpAll(() async {
    // Onboarded state gates the router redirect; tests start past onboarding.
    SharedPreferences.setMockInitialValues({'athena.onboarding.complete': true});
    await UserPreferences.instance.load();
  });

  testWidgets('app shell renders bottom navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          feedRepositoryProvider.overrideWithValue(_NoopFeedRepo()),
          paperRepositoryProvider.overrideWithValue(_NoopPaperRepo()),
        ],
        child: MaterialApp.router(routerConfig: buildAppRouter()),
      ),
    );
    // The wisdom banner's owl crest repeats forever; pumpAndSettle never
    // settles, so pump fixed durations instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Your Feed'), findsNothing); // legacy header, removed
    expect(find.text('ATHENA'), findsOneWidget); // current feed header
  });
}
