import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/prefs_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../../core/widgets/paper_card.dart';
import '../../papers/domain/audio_playback.dart';
import '../../papers/domain/paper.dart';
import '../../papers/presentation/audio_player_notifier.dart';
import '../../papers/presentation/paper_audio_player_screen.dart';
import '../domain/feed.dart';
import 'feed_notifier.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  FeedSection _section = FeedSection.latest;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 350) {
      ref.read(feedNotifierProvider(_section).notifier).loadMore();
    }
  }

  static String _formattedDate() {
    final now = DateTime.now();
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    const weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    final wd = weekdays[now.weekday - 1];
    final m = months[now.month - 1];
    return '$wd, $m ${now.day}';
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning, ';
    if (hour < 17) return 'Good afternoon, ';
    return 'Good evening, ';
  }

  static String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _openPlayer(BuildContext context, [AudioTrack? track, PaperSummary? paper]) {
    final notifier = ref.read(audioPlayerProvider.notifier);
    if (track != null) {
      notifier.playTrack(track);
    } else if (paper != null) {
      notifier.playPaper(paper);
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const PaperAudioPlayerScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final async = ref.watch(feedNotifierProvider(_section));
    final items = async.valueOrNull?.items ?? [];
    final audioState = ref.watch(audioPlayerProvider);
    final currentTrack = audioState.currentTrack;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => ref.read(feedNotifierProvider(_section).notifier).refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Top Header: Date, ATHENA Brand & Avatar
                  SliverToBoxAdapter(
                    child: AnimatedEntrance(
                      delay: const Duration(milliseconds: 50),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formattedDate(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          _greeting(),
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 22,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                        Text(
                                          'ATHENA',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                            color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                        size: 20,
                                      ),
                                      onPressed: () => ref.read(appThemeModeProvider.notifier).toggle(),
                                    ),
                                    const SizedBox(width: 4),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB),
                                      child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF141416)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Search Bar
                  SliverToBoxAdapter(
                    child: AnimatedEntrance(
                      delay: const Duration(milliseconds: 100),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                        child: InkWell(
                          onTap: () => context.go('/search'),
                          borderRadius: BorderRadius.circular(28),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1C2028) : Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 20,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Search topics, sources, voices…',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Screen 2: "TODAY'S RESEARCH BRIEF" Warm Yellow Highlight Card
                  SliverToBoxAdapter(
                    child: AnimatedEntrance(
                      delay: const Duration(milliseconds: 150),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.canaryYellow,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.canaryYellow.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141416),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      "TODAY'S RESEARCH BRIEF",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    items.isNotEmpty ? '${(items.length * 3.5).round()} MIN AUDIO' : '18 MIN AUDIO',
                                    style: const TextStyle(
                                      color: Color(0xFF141416),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                items.isNotEmpty
                                    ? 'Daily Drop: ${items.length} new papers in your subscribed fields.'
                                    : 'Daily Drop: 6 frontier papers, synthesized into one brief.',
                                style: const TextStyle(
                                  color: Color(0xFF141416),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                items.isNotEmpty
                                    ? 'Federated from arXiv & Semantic Scholar · ${items.first.paper.venueName.isNotEmpty ? items.first.paper.venueName : "AI & ML"}'
                                    : 'Federated from arXiv & Semantic Scholar · Machine Learning & AI',
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF141416),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (items.isNotEmpty) {
                                        _openPlayer(context, null, items.first.paper);
                                      } else {
                                        _openPlayer(context);
                                      }
                                    },
                                    child: const Row(
                                      children: [
                                        Icon(Icons.auto_stories_rounded, size: 14, color: AppTheme.canaryYellow),
                                        SizedBox(width: 6),
                                        Text('Read & digest', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF141416),
                                      side: const BorderSide(color: Color(0xFF141416), width: 1.2),
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    onPressed: () {
                                      if (items.isNotEmpty) {
                                        final track = AudioTrack.fromPaper(
                                          id: items.first.paper.id,
                                          title: items.first.paper.title,
                                          venue: items.first.paper.venueName,
                                          year: items.first.paper.year,
                                        );
                                        ref.read(audioPlayerProvider.notifier).addToQueue(track);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Added paper to your reading queue'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      } else {
                                        context.go('/saved');
                                      }
                                    },
                                    child: const Text('Queue', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Section: "READING PROGRESS & RECENT PAPERS"
                  if (audioState.recentTracks.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: AnimatedEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'READING PROGRESS & RECENT PAPERS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/saved'),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Library',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF7675)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Continue listening cards
                    SliverToBoxAdapter(
                      child: AnimatedEntrance(
                        delay: const Duration(milliseconds: 250),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              for (final track in audioState.recentTracks.take(2)) ...[
                                _ContinueListeningTile(
                                  track: track,
                                  isPlaying: audioState.isPlaying && audioState.currentTrack?.id == track.id,
                                  onPlay: () => _openPlayer(context, track),
                                  onTap: () => track.paperId != null ? context.push('/papers/${track.paperId}') : _openPlayer(context, track),
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Section: "EXPLORE FIELDS"
                  SliverToBoxAdapter(
                    child: AnimatedEntrance(
                      delay: const Duration(milliseconds: 300),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'EXPLORE FIELDS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/topics'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const Text(
                                'All topics',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFFF7675)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Horizontal Fields Carousel
                  SliverToBoxAdapter(
                    child: AnimatedEntrance(
                      delay: const Duration(milliseconds: 350),
                      child: SizedBox(
                        height: 135,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _CollectionCard(
                              title: 'Machine Learning',
                              subtitle: 'cs.LG · Deep representations',
                              colors: const [Color(0xFF1E3C72), Color(0xFF2A5298)],
                              onTap: () => context.push('/topics/machine-learning'),
                            ),
                            _CollectionCard(
                              title: 'Frontier AI & LLMs',
                              subtitle: 'cs.AI · Reasoning & scaling',
                              colors: const [Color(0xFF134E5E), Color(0xFF71B280)],
                              onTap: () => context.push('/topics/artificial-intelligence'),
                            ),
                            _CollectionCard(
                              title: 'Quantum Physics',
                              subtitle: 'quant-ph · Entanglement',
                              colors: const [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
                              onTap: () => context.push('/topics/quantum-physics'),
                            ),
                            _CollectionCard(
                              title: 'Neuroscience',
                              subtitle: 'q-bio.NC · Neural dynamics',
                              colors: const [Color(0xFFD48166), Color(0xFF373B44)],
                              onTap: () => context.push('/topics/neuroscience'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Section Switcher (Latest / Trending)
                  SliverToBoxAdapter(
                    child: AnimatedEntrance(
                      delay: const Duration(milliseconds: 400),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SegmentedButton<FeedSection>(
                              segments: const [
                                ButtonSegment(
                                  value: FeedSection.latest,
                                  label: Text('Latest'),
                                  icon: Icon(Icons.schedule_rounded, size: 16),
                                ),
                                ButtonSegment(
                                  value: FeedSection.trending,
                                  label: Text('Trending'),
                                  icon: Icon(Icons.trending_up_rounded, size: 16),
                                ),
                              ],
                              selected: {_section},
                              showSelectedIcon: false,
                              onSelectionChanged: (s) {
                                setState(() => _section = s.first);
                                if (_scrollController.hasClients) {
                                  _scrollController.jumpTo(0);
                                }
                              },
                            ),
                            if (items.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C2028) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2E3340) : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Text(
                                  '${items.length} papers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Feed list
                  if (items.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final item = items[i];
                          final isTrending = _section == FeedSection.trending;
                          return AnimatedEntrance(
                            delay: Duration(milliseconds: 30 * (i % 6)),
                            child: PaperCard(
                              paper: item.paper,
                              badge: isTrending
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: i < 3
                                            ? AppTheme.canaryYellow
                                            : (isDark ? const Color(0xFF222736) : const Color(0xFFF1F3F7)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '#${i + 1}',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: i < 3 ? const Color(0xFF141416) : (isDark ? Colors.white : const Color(0xFF141416)),
                                        ),
                                      ),
                                    )
                                  : null,
                              onTap: () => context.push('/papers/${item.paper.id}'),
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),

                  if (async.valueOrNull?.loadingMore == true)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        ),
                      ),
                    )
                  else if (async.valueOrNull != null && async.valueOrNull!.cursor == null && items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            "You've reached the end of today's papers",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ),
                ],
              ),
            ),

            // Persistent Floating Mini-Player Bar (Screen 2 bottom bar - bound to real audioPlayerProvider)
            if (currentTrack != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: AnimatedEntrance(
                  delay: const Duration(milliseconds: 450),
                  child: InkWell(
                    onTap: () => _openPlayer(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE89A84), Color(0xFFD66D75)],
                              ),
                            ),
                            child: const Icon(Icons.auto_stories_rounded, size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentTrack.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatDuration(audioState.currentPosition)} / ${_formatDuration(currentTrack.totalDuration)} · ${audioState.speed}x',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              audioState.isPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_filled_rounded,
                              color: AppTheme.canaryYellow,
                              size: 34,
                            ),
                            onPressed: () => ref.read(audioPlayerProvider.notifier).togglePlayPause(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF9CA3AF),
                              size: 20,
                            ),
                            tooltip: 'Close player',
                            onPressed: () => ref.read(audioPlayerProvider.notifier).stopAndDismiss(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueListeningTile extends StatelessWidget {
  const _ContinueListeningTile({
    required this.track,
    required this.isPlaying,
    required this.onPlay,
    required this.onTap,
    required this.isDark,
  });

  final AudioTrack track;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback? onTap;
  final bool isDark;

  static const _gradients = [
    [Color(0xFFE89A84), Color(0xFFD66D75)],
    [Color(0xFF6A11CB), Color(0xFF2575FC)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFF512F), Color(0xFFDD2476)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[track.gradientThemeIndex % _gradients.length];

    return InkWell(
      onTap: onTap ?? onPlay,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2028) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: colors),
              ),
              child: Icon(
                isPlaying ? Icons.graphic_eq_rounded : Icons.auto_stories_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF141416),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'IN PROGRESS',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.canaryYellow,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${track.authorVenue} · ${track.totalDuration.inMinutes}m digest',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPlaying ? AppTheme.canaryYellow : const Color(0xFF141416),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: isPlaying ? const Color(0xFF141416) : Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
