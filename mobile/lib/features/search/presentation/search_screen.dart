import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/prefs_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../../core/widgets/paper_card.dart';
import '../domain/search.dart';
import 'search_notifier.dart';
import 'topic_suggestions_provider.dart';
import 'widgets/search_filters_sheet.dart';

/// Friendly provider names for federated-search telemetry chips.
const _sourceLabels = {
  'arxiv': 'arXiv',
  'semanticscholar': 'Semantic Scholar',
  'openalex': 'OpenAlex',
  'crossref': 'Crossref',
  'europepmc': 'Europe PMC',
};

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchNotifierProvider.notifier).submit(widget.initialQuery!.trim());
      });
    }
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialQuery != null &&
        widget.initialQuery!.trim().isNotEmpty &&
        widget.initialQuery != oldWidget.initialQuery) {
      _controller.text = widget.initialQuery!.trim();
      ref.read(searchNotifierProvider.notifier).submit(widget.initialQuery!.trim());
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _shouldShowSuggestions {
    final query = _controller.text.trim();
    if (query.length < 2) return false;
    final state = ref.read(searchNotifierProvider);
    if (!state.submitted) return true;
    return _focus.hasFocus && query.toLowerCase() != state.filters.query.toLowerCase();
  }

  int _activeFilterCount(SearchFilters f) {
    int count = 0;
    if (f.mode != SearchMode.hybrid) count++;
    if (f.openAccess == true) count++;
    if (f.minCitations != null && f.minCitations! > 0) count++;
    if (f.publishedAfter != null) count++;
    if (f.sort != SearchSort.relevance) count++;
    return count;
  }

  void _showFiltersSheet(BuildContext context, SearchFilters current) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchFiltersSheet(
        currentFilters: current,
        onApply: (updated) {
          ref.read(searchNotifierProvider.notifier).applyAdvancedFilters(
            mode: updated.mode,
            sort: updated.sort,
            openAccess: updated.openAccess,
            minCitations: updated.minCitations,
            publishedAfter: updated.publishedAfter,
            publishedBefore: updated.publishedBefore,
            source: updated.source,
            clearDates: updated.publishedAfter == null,
            clearMinCitations: updated.minCitations == null,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    final notifier = ref.read(searchNotifierProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AthenaTopBar(
        title: 'Search',
        showLeading: false,
      ),
      body: DotGridBackground(
        child: Column(
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
                        notifier.reset();
                        setState(() {});
                        _focus.requestFocus();
                      },
                    ),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (state.submitted && !_shouldShowSuggestions) ...[
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.tune_rounded, size: 14, color: AppTheme.coral),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                          if (_activeFilterCount(state.filters) > 0) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: const BoxDecoration(
                                color: AppTheme.coral,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_activeFilterCount(state.filters)}',
                                style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onPressed: () => _showFiltersSheet(context, state.filters),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.library_books_rounded, size: 15),
                      label: const Text('Corpus'),
                      selected: !state.filters.isLive,
                      onSelected: (_) => notifier.setLiveSearch(false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.travel_explore_rounded, size: 15),
                      label: const Text('Live Web'),
                      selected: state.filters.isLive,
                      onSelected: (_) => notifier.setLiveSearch(true),
                    ),
                    const SizedBox(width: 8),
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
      ),
    );
  }

  static AsyncValue<List<SearchResult>> _toList(AsyncValue<SearchPageState> page) => page.when(
        data: (s) => AsyncValue<List<SearchResult>>.data(s.results),
        error: (e, st) => AsyncValue<List<SearchResult>>.error(e, st),
        loading: () => const AsyncValue<List<SearchResult>>.loading(),
      );

  Widget _results(BuildContext context, SearchState state) {
    if (_shouldShowSuggestions) {
      return _buildSuggestions(context, _controller.text.trim());
    }

    if (!state.submitted) {
      return _idle(context);
    }

    final page = state.page;
    final notifier = ref.read(searchNotifierProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                    state.filters.isLive
                        ? 'Querying arXiv · Semantic Scholar · OpenAlex · Crossref · Europe PMC…'
                        : 'Searching indexed research corpus…',
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
          child: Column(
            children: [
              if (page.hasValue &&
                  (page.valueOrNull?.results.isEmpty ?? false) &&
                  !state.filters.isLive)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B202A) : const Color(0xFFFFF0ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C3240) : AppTheme.coral.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.travel_explore_rounded, color: AppTheme.coral, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No corpus matches. Expand search to the entire live web (arXiv, OpenAlex, Crossref)?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => notifier.setLiveSearch(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.coral,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Search Web', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: AsyncListView<SearchResult>(
                  value: _toList(page),
                  emptyIcon: Icons.search_off,
                  emptyTitle: 'No matching research',
                  emptySubtitle: state.filters.isLive
                      ? 'No papers found across research providers. Try fewer or broader terms.'
                      : 'No indexed papers found. Switch to Live Web to search across global repositories.',
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
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context, String query) {
    final notifier = ref.read(searchNotifierProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suggestionsAsync = ref.watch(topicSuggestionsProvider(query));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Direct search action card
          Card(
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? const Color(0xFF2C3240) : const Color(0xFFE5E7EB),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                _focus.unfocus();
                notifier.submit(query);
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_rounded, color: AppTheme.coral, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search for "$query"',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search corpus and federated web repositories',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ),
          suggestionsAsync.when(
            data: (topics) {
              if (topics.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 14, color: AppTheme.coral),
                        const SizedBox(width: 6),
                        Text(
                          'TOPIC & FIELD SUGGESTIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final topic in topics)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF242934) : const Color(0xFFF3F4F6),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _controller.text = topic.name;
                          _focus.unfocus();
                          notifier.submit(topic.name);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF252A36) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  topic.isField ? Icons.account_balance_rounded : Icons.tag_rounded,
                                  size: 18,
                                  color: AppTheme.coral,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic.name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      topic.parentName != null && topic.parentName!.isNotEmpty
                                          ? topic.parentName!
                                          : (topic.isField ? 'Academic Field' : 'Research Area'),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (topic.paperCountEstimate > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF222732) : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${topic.paperCountEstimate} papers',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Finding matching research topics…',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _idle(BuildContext context) {
    final notifier = ref.read(searchNotifierProvider.notifier);
    final history = ref.watch(searchHistoryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'RECENT SEARCHES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => ref.read(searchHistoryProvider.notifier).clear(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Clear all', style: TextStyle(fontSize: 11, color: AppTheme.coral)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final query in history)
                      InputChip(
                        avatar: const Icon(Icons.north_west_rounded, size: 12),
                        label: Text(query, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          _controller.text = query;
                          _focus.unfocus();
                          notifier.submit(query);
                        },
                        onDeleted: () => ref.read(searchHistoryProvider.notifier).remove(query),
                        deleteIcon: const Icon(Icons.close, size: 14),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF20242E) : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                ),
              ),
              child: const Icon(
                Icons.travel_explore_rounded,
                size: 36,
                color: AppTheme.coral,
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
              'One query fans out to arXiv, Semantic Scholar,\nOpenAlex, Crossref and Europe PMC — best matches first.',
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
                      _focus.unfocus();
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
              if (meta.modeUsed.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: meta.modeUsed == 'live'
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF262C3A) : const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    meta.modeUsed == 'live' ? 'LIVE WEB' : 'INDEXED CORPUS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: meta.modeUsed == 'live'
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                ),
            ],
          ),
          if (meta.sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final s in meta.sources) ...[
                  Tooltip(
                    message: s.ok
                        ? '${_sourceLabels[s.slug] ?? s.slug}: ${s.papers} papers returned'
                        : '${_sourceLabels[s.slug] ?? s.slug} failed: ${s.error ?? "unavailable"}',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.ok
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFFF7675).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: s.ok
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFFF7675).withValues(alpha: 0.3),
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
          ],
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
        color: AppTheme.coral.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: const TextStyle(
          color: AppTheme.coral,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
