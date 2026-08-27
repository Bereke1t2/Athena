import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        title: const Text('Search'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _controller,
              focusNode: _focus,
              hintText: 'Search all research sources…',
              textInputAction: TextInputAction.search,
              onSubmitted: (q) {
                _focus.unfocus();
                notifier.submit(q);
              },
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
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
              height: 44,
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
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
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
    if (!state.submitted) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.travel_explore,
                    size: 44, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 20),
              Text(
                'Search every source at once',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'One query fans out to arXiv, Semantic Scholar,\nOpenAlex and Crossref — best matches first.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final label in _sourceLabels.values)
                    Chip(
                      label: Text(label),
                      labelStyle:
                          theme.textTheme.labelSmall, // keep chips compact
                      visualDensity: VisualDensity.compact,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Querying arXiv · Semantic Scholar · OpenAlex · Crossref…',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          )
        else if (page.hasValue)
          _sourceSummary(context, page.valueOrNull!),        Expanded(
          child: AsyncListView<SearchResult>(
            value: _toList(page),
            emptyIcon: Icons.search_off,
            emptyTitle: 'No matching research',
            emptySubtitle:
                'Try fewer or different words. Questions in plain language work too.',
            onRetry: () => notifier.submit(_controller.text),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Text(
            '${meta.results.length} papers'
            '${meta.tookMs > 0 ? ' · ${_formatTook(meta.tookMs)}' : ''}',
            style: theme.textTheme.labelMedium,
          ),
          const Spacer(),
          for (final s in meta.sources) ...[
            Tooltip(
              message: s.ok
                  ? '${s.papers} results from ${_sourceLabels[s.slug] ?? s.slug}'
                  : '${_sourceLabels[s.slug] ?? s.slug} unavailable',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.ok ? Icons.check_circle : Icons.error_outline,
                    size: 13,
                    color: s.ok ? theme.colorScheme.primary : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _sourceLabels[s.slug] ?? s.slug,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: s.ok
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        score.toStringAsFixed(1),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
