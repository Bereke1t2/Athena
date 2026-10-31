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

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key});

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search topics, fields, and disciplines…',
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      notifier.search('');
                    },
                  ),
              ],
              onChanged: (val) {
                setState(() {});
                notifier.search(val);
              },
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              emptySubtitle: 'Try adjusting your search terms or filter selection.',
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
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(
                      children: [
                        if (t.parentName != null && t.parentName!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.coral.withValues(alpha: 0.18)
                                  : AppTheme.coralSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.parentName!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.coral,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            t.isField
                                ? '${t.paperCountEstimate} papers indexed'
                                : '${t.paperCountEstimate} papers',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
