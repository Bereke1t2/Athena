import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/core/router/app_router.dart';
import 'package:athena/features/feed/domain/feed.dart';
import 'package:athena/features/feed/domain/feed_repository.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:athena/features/papers/domain/paper_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PaperSummary _paper(String id) => PaperSummary(
      id: id,
      title: 'Scaling Laws for Neural LMs',
      abstract: 'We study scaling.',
      publishedOn: DateTime.utc(2026, 5, 11),
      year: 2026,
      venueName: 'NeurIPS',
      publicationType: 'conference_paper',
      oaStatus: 'gold',
      isOpenAccess: true,
      citedByCount: 12,
    );

FeedPage _emptyFeed() =>
    const FeedPage(items: [], nextCursor: null);

class FakeFeedRepo implements FeedRepository {
  @override
  Future<FeedPage> load({required FeedSection section, List<String> topics = const [], String? cursor, int limit = 20}) async =>
      _emptyFeed();
}

class FakePaperRepo implements PaperRepository {
  @override
  Future<PaperDetail> getById(String id) async => PaperDetail(
        summary: _paper(id),
        language: 'en',
        license: '',
        bestOaUrl: '',
        doi: '10.1/x',
        arxivId: '',
        authors: const [],
        topics: const [],
        versions: const [],
        referenceCount: 3,
        sources: const [],
      );
}

Future<void> _pump(WidgetTester tester, {required String location}) async {
  final router = buildAppRouter();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(FakeFeedRepo()),
        paperRepositoryProvider.overrideWithValue(FakePaperRepo()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  // The feed shell embeds WisdomBannerCard, whose owl crest repeats forever,
  // so pumpAndSettle would never return — pump fixed durations instead.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  // Navigate programmatically (deep links land on these same locations).
  router.go(location);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUpAll(() async {
    // Onboarded state gates the router redirect; tests start past onboarding.
    SharedPreferences.setMockInitialValues({'athena.onboarding.complete': true});
    await UserPreferences.instance.load();
  });

  testWidgets('canonical route /papers/{id} renders detail content',
      (tester) async {
    const id = '0197c0de-0000-7000-8000-000000000001';
    await _pump(tester, location: '/papers/$id');
    expect(find.text('Scaling Laws for Neural LMs'), findsOneWidget);
    expect(find.text('Abstract'), findsOneWidget);
  });

  testWidgets('custom-scheme deep link path /{uuid} redirects to the paper',
      (tester) async {
    const id = '0197c0de-0000-7000-8000-000000000009';
    await _pump(tester, location: '/$id'); // athena://paper/{id} lands here
    expect(find.text('Scaling Laws for Neural LMs'), findsOneWidget);
  });

  test('isUuid guards the catch-all route', () {
    expect(isUuid('0197c0de-0000-7000-8000-000000000001'), isTrue);
    expect(isUuid('not-a-uuid'), isFalse);
  });
}
