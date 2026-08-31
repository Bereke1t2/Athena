import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/search.dart';
import 'search_notifier.dart';

/// Friendly provider names for federated-search telemetry chips.
const _sourceLabels = {
  'arxiv': 'arXiv',
  'semanticscholar': 'Semantic Scholar',
  'openalex': 'OpenAlex',
  'crossref': 'Crossref',
};

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SearchBar(
              controller: _controller,
              focusNode: _focus,
              hintText: 'Search papers, DOIs, arXiv IDs, authors…',
              textInputAction: TextInputAction.search,
              onSubmitted: (q) {
                _focus.unfocus();
                notifier.submit(q);
              },
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _controller.clear();
                      setState(() {});
                      _focus.requestFocus();
                    },
                  ),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (state.submitted) ...[
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('Best match'),
                    selected: state.filters.sort == SearchSort.relevance,
                    onSelected: (_) => notifier.setSort(SearchSort.relevance),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Newest'),
                    selected: state.filters.sort == SearchSort.newest,
                    onSelected: (_) => notifier.setSort(SearchSort.newest),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Most cited'),
                    selected: state.filters.sort == SearchSort.citations,
                    onSelected: (_) => notifier.setSort(SearchSort.citations),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Open access'),
                    selected: state.filters.openAccess ?? false,
                    showCheckmark: false,
                    onSelected: notifier.setOpenAccessOnly,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ],
          Expanded(child: _results(context, state)),
        ],
      ),
    );
  }

  static AsyncValue<List<SearchResult>> _toList(AsyncValue<SearchPageState> page) => page.when(
        data: (s) => AsyncValue<List<SearchResult>>.data(s.results),
        error: (e, st) => AsyncValue<List<SearchResult>>.error(e, st),
        loading: () => const AsyncValue<List<SearchResult>>.loading(),
      );

  Widget _results(BuildContext context, SearchState state) {
    final notifier = ref.read(searchNotifierProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!state.submitted) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF20242E) : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  size: 40,
                  color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Search every source at once',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'One query fans out to arXiv, Semantic Scholar,\nOpenAlex and Crossref — best matches first.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final label in _sourceLabels.values)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C2028) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              // Popular research suggestions
              Text(
                'TRENDING TOPICS',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final topic in [
                    'Scaling Laws',
                    'Diffusion Models',
                    'Reasoning & LLMs',
                    'Transformers',
                    'Reinforcement Learning',
                    'Mechanistic Interpretability',
                  ])
                    ActionChip(
                      label: Text(topic),
                      onPressed: () {
                        _controller.text = topic;
                        notifier.submit(topic);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final page = state.page;

    return Column(
      children: [
        if (page.isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Querying arXiv · Semantic Scholar · OpenAlex · Crossref…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          )
        else if (page.hasValue)
          _sourceSummary(context, page.valueOrNull!),
        Expanded(
          child: AsyncListView<SearchResult>(
            value: _toList(page),
            emptyIcon: Icons.search_off,
            emptyTitle: 'No matching research',
            emptySubtitle:
                'Try fewer or different words. Questions in plain language work too.',
            onRetry: () => notifier.submit(_controller.text),
            onLoadMore: () => notifier.loadMore(),
            isLoadingMore: page.valueOrNull?.loadingMore ?? false,
            footerVisible: page.valueOrNull?.cursor != null,
            itemBuilder: (context, r) => PaperCard(
              paper: r.paper,
              onTap: () => context.push('/papers/${r.paper.id}'),
              badge: r.score > 0 ? _ScoreBadge(score: r.score) : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sourceSummary(BuildContext context, SearchPageState meta) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${meta.results.length} papers'
                '${meta.tookMs > 0 ? ' · ${_formatTook(meta.tookMs)}' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2430) : const Color(0xFFEFF2F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Federated search',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in meta.sources) ...[
                  Tooltip(
                    message: s.ok
                        ? '${s.papers} results from ${_sourceLabels[s.slug] ?? s.slug}'
                        : '${_sourceLabels[s.slug] ?? s.slug} unavailable',
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 12,
                            color: s.ok ? const Color(0xFF10B981) : const Color(0xFFFF7675),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_sourceLabels[s.slug] ?? s.slug}${s.ok ? ' (${s.papers})' : ''}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTook(int ms) =>
      ms >= 1000 ? '${(ms / 1000).toStringAsFixed(1)}s' : '${ms}ms';
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: AppTheme.canaryYellow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: const TextStyle(
          color: AppTheme.canaryYellow,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
