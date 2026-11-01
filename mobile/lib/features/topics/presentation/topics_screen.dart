import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../../core/widgets/paper_card.dart';
import '../../follows/presentation/follows_notifier.dart';
import '../domain/topic.dart';
import 'topics_notifier.dart';

AsyncValue<List<Topic>> _list(AsyncValue<TopicListState> page) => page.when(
      data: (s) => AsyncValue<List<Topic>>.data(s.items),
      error: (e, st) => AsyncValue<List<Topic>>.error(e, st),
      loading: () => const AsyncValue<List<Topic>>.loading(),
);

class TopicsScreen extends ConsumerStatefulWidget {
  const TopicsScreen({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  ConsumerState<TopicsScreen> createState() => _TopicsScreenState();
}

class _TopicsScreenState extends ConsumerState<TopicsScreen> {
  final _searchController = TextEditingController();
  late String _selectedSegment;

  @override
  void initState() {
    super.initState();
    _selectedSegment = widget.initialFilter ?? '';
  }

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
    final followsState = ref.watch(followsNotifierProvider);

    // If 'following' segment is selected, curate from followed topics
    AsyncValue<List<Topic>> listValue;
    if (_selectedSegment == 'following') {
      final query = _searchController.text.trim().toLowerCase();
      final corpusItems = async.valueOrNull?.items ?? const <Topic>[];
      final corpusMap = {for (final t in corpusItems) t.slug.toLowerCase(): t};

      final items = followsState.followedTopics.map((f) {
        final existing = corpusMap[f.topicSlug.toLowerCase()];
        if (existing != null) return existing;
        return Topic(
          slug: f.topicSlug,
          name: f.topicName,
          kind: 'topic',
          paperCountEstimate: 0,
        );
      }).where((t) {
        if (query.isEmpty) return true;
        return t.name.toLowerCase().contains(query) || t.slug.toLowerCase().contains(query);
      }).toList();

      listValue = AsyncValue.data(items);
    } else {
      listValue = _list(async);
    }

    return Scaffold(
      appBar: const AthenaTopBar(
        title: 'Topics',
        showLeading: false,
      ),
      body: DotGridBackground(
        child: Column(
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
                      if (_selectedSegment != 'following') {
                        notifier.search('');
                      }
                    },
                  ),
              ],
              onChanged: (val) {
                setState(() {});
                if (_selectedSegment != 'following') {
                  notifier.search(val);
                }
              },
              elevation: const WidgetStatePropertyAll(0),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('All')),
                ButtonSegment(value: 'following', label: Text('Following')),
                ButtonSegment(value: 'field', label: Text('Fields')),
                ButtonSegment(value: 'topic', label: Text('Topics')),
              ],
              selected: {_selectedSegment},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                final chosen = s.first;
                setState(() => _selectedSegment = chosen);
                if (chosen != 'following') {
                  notifier.setKind(chosen);
                }
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AsyncListView<Topic>(
              value: listValue,
              onRetry: _selectedSegment == 'following' ? () async {} : notifier.refresh,
              onLoadMore: _selectedSegment == 'following' ? () async {} : notifier.loadMore,
              isLoadingMore: _selectedSegment == 'following' ? false : (async.valueOrNull?.loadingMore ?? false),
              footerVisible: _selectedSegment == 'following' ? false : (async.valueOrNull?.cursor != null),
              emptyIcon: _selectedSegment == 'following' ? Icons.bookmark_border_rounded : Icons.category_outlined,
              emptyTitle: _selectedSegment == 'following' ? 'No followed topics' : 'No topics found',
              emptySubtitle: _selectedSegment == 'following'
                  ? 'You haven\'t subscribed to any topics yet. Switch to All or Fields to follow areas of interest.'
                  : 'Try adjusting your search terms or filter selection.',
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
                      color: AppTheme.coral,
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FollowTopicButton(
                        isFollowed: followsState.isTopicFollowed(t.slug),
                        isDark: isDark,
                        onPressed: () {
                          ref.read(followsNotifierProvider.notifier).toggleTopicFollow(t.slug, t.name);
                        },
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF222632) : const Color(0xFFF0F2F5),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                      ),
                    ],
                  ),
                  onTap: () => context.push('/topics/${t.slug}'),
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

class _FollowTopicButton extends StatelessWidget {
  const _FollowTopicButton({
    required this.isFollowed,
    required this.isDark,
    required this.onPressed,
  });

  final bool isFollowed;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isFollowed) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(
            color: isDark ? const Color(0xFF333A4D) : const Color(0xFFD1D5DB),
          ),
          backgroundColor: isDark ? const Color(0xFF232836) : const Color(0xFFF3F4F6),
          foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: 13, color: AppTheme.coral),
        label: const Text('Following', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
    }

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: AppTheme.coral.withValues(alpha: 0.12),
        foregroundColor: AppTheme.coral,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 13),
      label: const Text('Follow', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
