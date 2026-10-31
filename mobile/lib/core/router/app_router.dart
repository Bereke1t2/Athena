import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../features/ai/presentation/chat_screen.dart';
import '../../features/ai/presentation/create_audio_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/comparison/presentation/comparison_screen.dart';
import '../../features/digest/presentation/digest_screen.dart';
import '../../features/feed/presentation/feed_screen.dart';
import '../../features/library/presentation/saved_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/papers/presentation/article_reader_screen.dart';
import '../../features/papers/presentation/paper_audio_player_screen.dart';
import '../../features/papers/presentation/paper_detail_screen.dart';
import '../../features/papers/presentation/pdf_viewer_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
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
            GoRoute(
              path: '/search',
              name: 'search',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: SearchScreen(initialQuery: state.uri.queryParameters['q']),
                transitionsBuilder: (_, __, ___, child) => child,
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/topics', name: 'topics', pageBuilder: _noTransition(TopicsScreen.new)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/digest', name: 'digest-tab', pageBuilder: _noTransition(DigestScreen.new)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/saved', name: 'saved-tab', pageBuilder: _noTransition(SavedScreen.new)),
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
        path: '/papers/:id/reader',
        name: 'paper-reader',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ArticleReaderScreen(
          paperId: state.pathParameters['id']!,
          title: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/create-audio',
        name: 'create-audio',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CreateAudioScreen(
          paperId: state.uri.queryParameters['paperId'],
          initialTitle: state.uri.queryParameters['title'],
        ),
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PaperAudioPlayerScreen(),
      ),
      GoRoute(
        path: '/saved',
        name: 'saved',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SavedScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/digest',
        name: 'digest',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DigestScreen(),
      ),
      GoRoute(
        path: '/compare',
        name: 'compare',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final idsParam = state.uri.queryParameters['ids'];
          final idsList = idsParam != null && idsParam.isNotEmpty
              ? idsParam.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
              : (state.extra is List<String> ? state.extra! as List<String> : <String>[]);
          return ComparisonScreen(initialPaperIds: idsList);
        },
      ),
      // Custom-scheme deep link landing zone: athena://paper/{token} parses to
      // path /{token}. UUID, arXiv ID, or DOI segments are treated as paper links.
      GoRoute(
        path: '/:token',
        redirect: (context, state) {
          final token = state.pathParameters['token']!;
          return isPaperToken(token) ? '/papers/$token' : '/';
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

bool isPaperToken(String s) {
  if (_uuidRe.hasMatch(s)) return true;
  // arXiv ID format: e.g. 2403.12345 or 2301.00001v2
  if (RegExp(r'^\d{4}\.\d{4,5}(v\d+)?$').hasMatch(s) || s.startsWith('arxiv:')) return true;
  // DOI format: e.g. 10.1145/... or doi:...
  if (s.startsWith('10.') || s.startsWith('doi:')) return true;
  return false;
}

class _HomeShell extends StatelessWidget {
  const _HomeShell(this.shell);

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111216) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF222632) : const Color(0xFFE5E7EB),
              width: 1.0,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            height: 64,
            elevation: 0,
            backgroundColor: Colors.transparent,
            indicatorColor: isDark
                ? AppTheme.coral.withValues(alpha: 0.18)
                : AppTheme.coralSubtle,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppTheme.coral),
                label: 'Feed',
              ),
              NavigationDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description_rounded, color: AppTheme.coral),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.category_outlined),
                selectedIcon: Icon(Icons.category_rounded, color: AppTheme.coral),
                label: 'Topics',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded, color: AppTheme.coral),
                label: 'Digest',
              ),
              NavigationDestination(
                icon: Icon(Icons.assignment_turned_in_outlined),
                selectedIcon: Icon(Icons.assignment_turned_in_rounded, color: AppTheme.coral),
                label: 'Saved',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
