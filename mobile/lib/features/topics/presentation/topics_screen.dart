import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/paper_card.dart';
import '../domain/topic.dart';
import 'topics_notifier.dart';

AsyncValue<List<Topic>> _list(AsyncValue<TopicListState> page) => page.when(
      data: (s) => AsyncValue<List<Topic>>.data(s.items),
      error: (e, st) => AsyncValue<List<Topic>>.error(e, st),
      loading: () => const AsyncValue<List<Topic>>.loading(),
);

class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(topicListNotifierProvider);
    final notifier = ref.read(topicListNotifierProvider.notifier);
    final kind = async.valueOrNull?.kindFilter ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Topics')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('All')),
                ButtonSegment(value: 'field', label: Text('Fields')),
                ButtonSegment(value: 'topic', label: Text('Topics')),
              ],
              selected: {kind},
              onSelectionChanged: (s) => notifier.setKind(s.first),
            ),
          ),
          Expanded(
            child: AsyncListView<Topic>(
              value: _list(async),
              onRetry: notifier.refresh,
              onLoadMore: notifier.loadMore,
              isLoadingMore: async.valueOrNull?.loadingMore ?? false,
              footerVisible: async.valueOrNull?.cursor != null,
              emptyIcon: Icons.category_outlined,
              emptyTitle: 'No topics found',
              itemBuilder: (context, t) => Card(
                child: ListTile(
                  title: Text(t.name),
                  subtitle: Text(
                    t.isField
                        ? '${t.paperCountEstimate} papers'
                        : '${t.paperCountEstimate} papers${t.children.isNotEmpty ? ' · ${t.children.length} subtopics' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/topics/${t.slug}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
