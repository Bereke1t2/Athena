import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final async = ref.watch(topicListNotifierProvider);
    final notifier = ref.read(topicListNotifierProvider.notifier);
    final kind = async.valueOrNull?.kindFilter ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Topics',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('All')),
                ButtonSegment(value: 'field', label: Text('Fields')),
                ButtonSegment(value: 'topic', label: Text('Topics')),
              ],
              selected: {kind},
              showSelectedIcon: false,
              onSelectionChanged: (s) => notifier.setKind(s.first),
            ),
          ),
          const SizedBox(height: 6),
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
                elevation: 0,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF232734) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      t.isField ? Icons.auto_awesome_mosaic_rounded : Icons.label_outline_rounded,
                      size: 20,
                      color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                    ),
                  ),
                  title: Text(
                    t.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  subtitle: Text(
                    t.isField
                        ? '${t.paperCountEstimate} papers indexed'
                        : '${t.paperCountEstimate} papers${t.children.isNotEmpty ? ' · ${t.children.length} subtopics' : ''}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF222632) : const Color(0xFFF0F2F5),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  ),
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
