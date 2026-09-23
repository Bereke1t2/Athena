import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../follows/presentation/follows_notifier.dart';
import '../domain/topic.dart';
import 'topics_notifier.dart';

class TopicDetailScreen extends ConsumerWidget {
  const TopicDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicAsync = ref.watch(topicDetailControllerProvider(slug));
    final papersAsync = ref.watch(topicPapersNotifierProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(topicAsync.valueOrNull?.name ?? 'Topic')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topicDetailControllerProvider(slug));
          ref.invalidate(topicPapersNotifierProvider(slug));
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 350) {
              final page = papersAsync.valueOrNull;
              if (page?.nextCursor != null) {
                ref.read(topicPapersNotifierProvider(slug).notifier).loadMore();
              }
            }
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              topicAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  failure: e,
                  onRetry: () => ref.invalidate(topicDetailControllerProvider(slug)),
                ),
                data: (topic) => _header(context, ref, topic),
              ),
              const Divider(height: 24),
              papersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  failure: e,
                  onRetry: () => ref.invalidate(topicPapersNotifierProvider(slug)),
                ),
                data: (page) {
                  final theme = Theme.of(context);
                  if (page.items.isEmpty) {
                    return const EmptyView(
                      icon: Icons.article_outlined,
                      title: 'No papers under this topic yet',
                    );
                  }
                  return Column(
                    children: [
                      for (final p in page.items)
                        PaperCard(paper: p, onTap: () => context.push('/papers/${p.id}')),
                      if (page.nextCursor != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              "End of papers for this topic",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, Topic topic) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final followsState = ref.watch(followsNotifierProvider);
    final isFollowed = followsState.isTopicFollowed(topic.slug);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(label: Text(topic.isField ? 'Field' : 'Topic')),
                    Chip(label: Text('${topic.paperCountEstimate} papers')),
                    if (topic.parentName != null)
                      Chip(label: Text('in ${topic.parentName!}')),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowed
                      ? (isDark ? const Color(0xFF232836) : const Color(0xFFE5E7EB))
                      : AppTheme.canaryYellow,
                  foregroundColor: isFollowed
                      ? (isDark ? Colors.white : const Color(0xFF141416))
                      : const Color(0xFF141416),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ref.read(followsNotifierProvider.notifier).toggleTopicFollow(topic.slug, topic.name);
                },
                icon: Icon(isFollowed ? Icons.check_rounded : Icons.add_rounded, size: 16),
                label: Text(
                  isFollowed ? 'Following' : 'Follow Topic',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (topic.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(topic.description, style: theme.textTheme.bodyMedium),
          ],
          if (topic.children.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Subtopics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in topic.children)
                  ActionChip(
                    label: Text(Topic.displayNameForSlug(c)),
                    onPressed: () => context.push('/topics/$c'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
