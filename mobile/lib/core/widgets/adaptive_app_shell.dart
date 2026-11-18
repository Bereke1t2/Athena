import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/papers/presentation/widgets/mini_audio_player.dart';
import '../theme/app_theme.dart';

/// Breakpoint for switching between mobile bottom navigation and wide-screen navigation rail.
const double kTabletBreakpoint = 720.0;

/// Max content width for wide/desktop viewports to maintain comfortable reading ergonomics.
const double kMaxContentWidth = 1200.0;

/// Adaptive application shell providing responsive layout:
/// - NavigationRail on wider viewports (tablet, desktop, web: >= 720px) with centered content.
/// - NavigationBar docked at bottom on standard mobile viewports (< 720px).
class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    super.key,
    required this.shell,
  });

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= kTabletBreakpoint;

    return isWide ? _buildWideLayout(context) : _buildMobileLayout(context);
  }

  Widget _buildWideLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111216) : Colors.white,
              border: Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF222632) : const Color(0xFFE5E7EB),
                  width: 1.0,
                ),
              ),
            ),
            child: SafeArea(
              child: NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: shell.goBranch,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.transparent,
                indicatorColor: isDark
                    ? AppTheme.coral.withValues(alpha: 0.18)
                    : AppTheme.coralSubtle,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.coral.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppTheme.coral.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppTheme.coral,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'ATHENA',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppTheme.coral,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded, color: AppTheme.coral),
                    label: Text('Feed'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.description_outlined),
                    selectedIcon: Icon(Icons.description_rounded, color: AppTheme.coral),
                    label: Text('Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.category_outlined),
                    selectedIcon: Icon(Icons.category_rounded, color: AppTheme.coral),
                    label: Text('Topics'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.auto_stories_outlined),
                    selectedIcon: Icon(Icons.auto_stories_rounded, color: AppTheme.coral),
                    label: Text('Digest'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_library_outlined),
                    selectedIcon: Icon(Icons.local_library_rounded, color: AppTheme.coral),
                    label: Text('Library'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                      child: shell,
                    ),
                  ),
                ),
                const MiniAudioPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniAudioPlayer(),
          Container(
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
                    icon: Icon(Icons.auto_stories_outlined),
                    selectedIcon: Icon(Icons.auto_stories_rounded, color: AppTheme.coral),
                    label: 'Digest',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.local_library_outlined),
                    selectedIcon: Icon(Icons.local_library_rounded, color: AppTheme.coral),
                    label: 'Library',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
