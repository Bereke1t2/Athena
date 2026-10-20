import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/saved_papers.dart';
import '../../../core/theme/app_theme.dart';
import '../../history/presentation/history_notifier.dart';
import '../../papers/presentation/paper_audio_player_screen.dart';

/// The research library: saved papers and reading progress history.
class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final saved = ref.watch(savedPapersProvider);
    final historyState = ref.watch(historyNotifierProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text(
            'Library',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.canaryYellow,
            labelColor: isDark ? Colors.white : const Color(0xFF141416),
            unselectedLabelColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: [
              Tab(text: 'Saved (${saved.length})'),
              const Tab(text: 'Reading History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Saved Papers
            saved.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.headphones_rounded,
                              size: 42,
                              color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Your library is empty',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Bookmark any research paper or audio episode to listen and study offline.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: saved.length,
                    itemBuilder: (context, i) {
                      final p = saved[i];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => context.push('/papers/${p.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE89A84), Color(0xFFD66D75)],
                                    ),
                                  ),
                                  child: const Icon(Icons.headphones_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (p.venue.isNotEmpty) p.venue,
                                          if (p.year > 0) '${p.year}',
                                          '${p.citedByCount} citations',
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.play_circle_fill_rounded, size: 32),
                                  color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                  tooltip: 'Play audio',
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        fullscreenDialog: true,
                                        builder: (_) => PaperAudioPlayerScreen(
                                          title: p.title,
                                          source: '${p.venue} · ${p.year}',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.bookmark, size: 20),
                                  tooltip: 'Remove',
                                  onPressed: () =>
                                      ref.read(savedPapersProvider.notifier).remove(p.id),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // Tab 2: Reading History
            historyState.isLoading && historyState.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : historyState.items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.history_rounded,
                                  size: 42,
                                  color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No reading history yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Papers you read in the article reader or PDF viewer will appear here with your progress.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'RECENTLY READ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Clear reading history?'),
                                        content: const Text('This will remove all reading progress history across devices.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF7675))),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(historyNotifierProvider.notifier).clearHistory();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: historyState.items.length,
                              itemBuilder: (context, i) {
                                final entry = historyState.items[i];
                                final paper = entry.paper;
                                final pct = entry.progressPercent.clamp(0.0, 100.0);

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.symmetric(vertical: 5),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => context.push('/papers/${paper.id}'),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            paper.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                          const SizedBox(height: 8),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: LinearProgressIndicator(
                                              value: pct / 100.0,
                                              minHeight: 5,
                                              backgroundColor: isDark
                                                  ? const Color(0xFF262B38)
                                                  : const Color(0xFFE5E7EB),
                                              color: entry.completed || pct >= 95
                                                  ? const Color(0xFF55EFC4)
                                                  : AppTheme.canaryYellow,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${pct.round()}% read · ${entry.completed || pct >= 95 ? "Completed" : "In progress"}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: entry.completed || pct >= 95
                                                      ? const Color(0xFF55EFC4)
                                                      : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563)),
                                                ),
                                              ),
                                              Text(
                                                '${entry.lastReadAt.day}/${entry.lastReadAt.month}/${entry.lastReadAt.year}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }
}
