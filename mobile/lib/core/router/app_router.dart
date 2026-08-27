import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/presentation/chat_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/library/presentation/saved_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/papers/presentation/paper_detail_screen.dart';
import '../../features/papers/presentation/pdf_viewer_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/topics/presentation/topic_detail_screen.dart';
import '../../features/topics/presentation/topics_screen.dart';
import '../prefs/user_preferences.dart';

/// App routes + deep links (`athena://paper/{id}` arrives at path `/{id}` on
/// custom schemes, hence the UUID-guarded catch-all below).
final _rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter buildAppRouter() {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = UserPreferences.instance.onboarded;
      final location = state.uri.path;
      if (!onboarded && location != '/onboarding') return '/onboarding';
      if (onboarded && location == '/onboarding') return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: _fadeTransition(OnboardingScreen.new),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HomeShell(shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', name: 'feed', pageBuilder: _noTransition(FeedScreen.new)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', name: 'search', pageBuilder: _noTransition(SearchScreen.new)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/topics', name: 'topics', pageBuilder: _noTransition(TopicsScreen.new)),
          ]),
        ],
      ),
      GoRoute(
        path: '/topics/:slug',
        name: 'topic-detail',
        builder: (context, state) =>
            TopicDetailScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/papers/:id',
        name: 'paper-detail',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PaperDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/papers/:id/chat',
        name: 'paper-chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ChatScreen(
          paperId: state.pathParameters['id']!,
          paperTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/papers/:id/pdf',
        name: 'paper-pdf',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PdfViewerScreen(
          paperId: state.pathParameters['id']!,
          url: state.uri.queryParameters['url'] ?? '',
          title: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/saved',
        name: 'saved',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedScreen(),
      ),
      // Custom-scheme deep link landing zone: athena://paper/{uuid} parses to
      // path /{uuid}. Only UUID-shaped segments are treated as paper links.
      GoRoute(
        path: '/:token',
        redirect: (context, state) {
          final token = state.pathParameters['token']!;
          return isUuid(token) ? '/papers/$token' : '/';
        },
      ),
    ],
  );
}

Page<dynamic> Function(BuildContext, GoRouterState) _noTransition(
  Widget Function() screen,
) {
  return (context, state) => NoTransitionPage(key: state.pageKey, child: screen());
}

Page<dynamic> Function(BuildContext, GoRouterState) _fadeTransition(
  Widget Function() screen,
) {
  return (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: screen(),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      );
}

final RegExp _uuidRe = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool isUuid(String s) => _uuidRe.hasMatch(s);

class _HomeShell extends StatelessWidget {
  const _HomeShell(this.shell);

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.feed_outlined), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.category_outlined), label: 'Topics'),
        ],
      ),
    );
  }
}
