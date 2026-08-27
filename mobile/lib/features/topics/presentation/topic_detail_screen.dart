import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/state_views.dart';
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
              data: (topic) => _header(context, topic),
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
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: OutlinedButton(
                          onPressed: () =>
                              ref.read(topicPapersNotifierProvider(slug).notifier).loadMore(),
                          child: const Text('Load more'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Topic topic) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(topic.isField ? 'Field' : 'Topic')),
              Chip(label: Text('${topic.paperCountEstimate} papers')),
              if (topic.parentName != null)
                Chip(label: Text('in ${topic.parentName!}')),
            ],
          ),
          if (topic.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(topic.description, style: theme.textTheme.bodyMedium),
          ],
          if (topic.children.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Subtopics', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              children: [for (final c in topic.children) ActionChip(label: Text(Topic.displayNameForSlug(c)), onPressed: () => context.push('/topics/$c'))],
            ),
          ],
        ],
      ),
    );
  }
}
