import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../prefs/user_preferences.dart';
import '../theme/app_theme.dart';

class _CommandItem {
  const _CommandItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.keywords = const [],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final List<String> keywords;

  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q)) return true;
    if (subtitle.toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

/// Global command palette spotlight dialog (Cmd+K / Ctrl+K).
/// Provides instant keyboard-driven navigation, recent queries, and search dispatch.
class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => const CommandPaletteDialog(),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  static const List<_CommandItem> _destinations = [
    _CommandItem(
      title: 'Home Research Feed',
      subtitle: 'Explore latest publications, recommendations, and field updates',
      icon: Icons.home_rounded,
      route: '/',
      keywords: ['feed', 'home', 'latest', 'discover'],
    ),
    _CommandItem(
      title: 'Search Corpus & Web',
      subtitle: 'Hybrid AI, vector semantics, and live federated search',
      icon: Icons.search_rounded,
      route: '/search',
      keywords: ['search', 'find', 'query', 'arxiv', 'lookup'],
    ),
    _CommandItem(
      title: 'Taxonomy & Fields',
      subtitle: 'Browse 300+ research fields, hierarchical topics, and subdisciplines',
      icon: Icons.category_rounded,
      route: '/topics',
      keywords: ['topics', 'fields', 'disciplines', 'categories'],
    ),
    _CommandItem(
      title: 'Weekly Research Digest',
      subtitle: 'Personalized editorial literature synthesis and audio briefing',
      icon: Icons.auto_stories_rounded,
      route: '/digest',
      keywords: ['digest', 'weekly', 'briefing', 'audio', 'podcast'],
    ),
    _CommandItem(
      title: 'My Library & Collections',
      subtitle: 'Bookmarks, reading lists, and collaborative research groups',
      icon: Icons.local_library_rounded,
      route: '/saved',
      keywords: ['library', 'bookmarks', 'saved', 'collections', 'collaborate'],
    ),
    _CommandItem(
      title: 'Downloads & Offline Storage',
      subtitle: 'Manage cached PDFs, storage breakdown, and flight packs',
      icon: Icons.storage_rounded,
      route: '/storage',
      keywords: ['storage', 'offline', 'downloads', 'pdf', 'flight'],
    ),
    _CommandItem(
      title: 'Paper Comparison Matrix',
      subtitle: 'Synthesize methodology, consensus, and divergence across papers',
      icon: Icons.compare_arrows_rounded,
      route: '/compare',
      keywords: ['compare', 'matrix', 'comparison', 'tray', 'synthesize'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _inputController.removeListener(_onQueryChanged);
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {});
  }

  void _executeSearch(String query) {
    final q = query.trim();
    if (q.isEmpty) return;
    Navigator.of(context, rootNavigator: true).pop();
    context.push('/search?q=${Uri.encodeComponent(q)}');
  }

  void _navigateToRoute(String route) {
    Navigator.of(context, rootNavigator: true).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final query = _inputController.text.trim();
    final recentSearches = UserPreferences.instance.searchHistory;

    final filteredDestinations = _destinations
        .where((d) => d.matches(query))
        .toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 520),
        child: Material(
          color: isDark ? const Color(0xFF161922) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.5),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Search Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1E29) : const Color(0xFFF9FAFB),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 22, color: AppTheme.coral),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _executeSearch,
                          decoration: InputDecoration(
                            hintText: 'Type a command, destination, or research query...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF141416),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ESC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content List
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Direct Search Action when query is entered
                      if (query.isNotEmpty) ...[
                        ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.coral.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.coral),
                          ),
                          title: Text(
                            'Search literature for "$query"',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF141416),
                            ),
                          ),
                          subtitle: Text(
                            'Run hybrid semantic and live federated search',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: const Icon(Icons.keyboard_return_rounded, size: 16),
                          onTap: () => _executeSearch(query),
                        ),
                        const Divider(height: 12),
                      ],

                      // Recent Searches Section (shown first when query is empty)
                      if (query.isEmpty && recentSearches.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Text(
                            'RECENT RESEARCH QUERIES',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        for (final q in recentSearches.take(4))
                          ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222736) : const Color(0xFFF1F3F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF9CA3AF)),
                            ),
                            title: Text(
                              q,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF141416),
                              ),
                            ),
                            trailing: const Icon(Icons.north_west_rounded, size: 13, color: Color(0xFF9CA3AF)),
                            onTap: () => _executeSearch(q),
                          ),
                        const Divider(height: 16),
                      ],

                      // Destinations Section
                      if (filteredDestinations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: Text(
                            'DESTINATIONS & WORKSPACES',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        for (final item in filteredDestinations)
                          ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222736) : const Color(0xFFF1F3F7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.icon,
                                size: 16,
                                color: isDark ? Colors.white70 : const Color(0xFF374151),
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF141416),
                              ),
                            ),
                            subtitle: Text(
                              item.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                            trailing: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                            ),
                            onTap: () => _navigateToRoute(item.route),
                          ),
                      ],
                    ],
                  ),
                ),

                // Footer Keyboard Hints
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF12141A) : const Color(0xFFF3F4F6),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildKeyHint('⌘K', 'Open Palette', isDark),
                        const SizedBox(width: 14),
                        _buildKeyHint('↵', 'Execute', isDark),
                        const SizedBox(width: 14),
                        _buildKeyHint('ESC', 'Dismiss', isDark),
                        const SizedBox(width: 20),
                        Text(
                          'Athena Command Palette',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyHint(String keyLabel, String actionLabel, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222736) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isDark ? const Color(0xFF373D4E) : const Color(0xFFD1D5DB),
            ),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          actionLabel,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
