import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/prefs_providers.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/feed.dart';
import 'feed_notifier.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  FeedSection _section = FeedSection.latest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final async = ref.watch(feedNotifierProvider(_section));
    final items = async.valueOrNull?.items ?? [];

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(feedNotifierProvider(_section).notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top Bar: Header with Athena Shield Badge & Theme Toggle
              SliverToBoxAdapter(
                child: AnimatedEntrance(
                  delay: const Duration(milliseconds: 50),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        // Athena Goddess Shield Brand Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ATHENA',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Goddess of Knowledge',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Theme Toggle Button (Light / Dark)
                        IconButton.filledTonal(
                          tooltip: 'Toggle Theme',
                          icon: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            size: 19,
                          ),
                          onPressed: () {
                            ref.read(appThemeModeProvider.notifier).toggle();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Section 1: "New Research" Featured Hero Card
              if (items.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: AnimatedEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        'New Research',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedEntrance(
                    delay: const Duration(milliseconds: 350),
                    child: FeaturedPaperCard(
                      paper: items.first.paper,
                      onTap: () => context.push('/papers/${items.first.paper.id}'),
                    ),
                  ),
                ),
              ],

              // Section 4: "Top Research" Horizontal Cover Carousel
              if (items.length > 1) ...[
                SliverToBoxAdapter(
                  child: AnimatedEntrance(
                    delay: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Text(
                        'Top Research',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedEntrance(
                    delay: const Duration(milliseconds: 450),
                    child: SizedBox(
                      height: 165,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: items.length - 1,
                        itemBuilder: (context, i) {
                          final item = items[i + 1];
                          return TopPaperCoverCard(
                            paper: item.paper,
                            onTap: () => context.push('/papers/${item.paper.id}'),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],

              // Section 5: Section Switcher & Feed List
              SliverToBoxAdapter(
                child: AnimatedEntrance(
                  delay: const Duration(milliseconds: 500),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: SegmentedButton<FeedSection>(
                      segments: const [
                        ButtonSegment(
                          value: FeedSection.latest,
                          label: Text('Latest'),
                          icon: Icon(Icons.schedule_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: FeedSection.trending,
                          label: Text('Trending'),
                          icon: Icon(Icons.trending_up_rounded, size: 18),
                        ),
                      ],
                      selected: {_section},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _section = s.first),
                    ),
                  ),
                ),
              ),

              // Feed Items List
              if (items.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final item = items[i];
                      return AnimatedEntrance(
                        delay: Duration(milliseconds: 50 * (i % 6)),
                        child: PaperCard(
                          paper: item.paper,
                          onTap: () => context.push('/papers/${item.paper.id}'),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
