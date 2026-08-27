import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../domain/ai_models.dart';
import 'summary_notifier.dart';

/// AI summary block for the paper detail screen: level selector + structured
/// sections, with honest "based on abstract" degradation labeling.
class PaperSummaryCard extends ConsumerStatefulWidget {
  const PaperSummaryCard({super.key, required this.paperId});

  final String paperId;

  @override
  ConsumerState<PaperSummaryCard> createState() => _PaperSummaryCardState();
}

class _PaperSummaryCardState extends ConsumerState<PaperSummaryCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(summaryNotifierProvider(widget.paperId));
    final notifier = ref.read(summaryNotifierProvider(widget.paperId).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI summary', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        // Level chips appear only once a summary exists (or is loading) —
        // generation is opt-in so no tokens are spent uninvited.
        if (state.data is AsyncData<PaperSummaryAI> ||
            state.data is AsyncLoading && state.data.hasValue != false)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                for (final level in ExplanationLevel.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(level.label),
                      selected: state.level == level,
                      onSelected: (_) => notifier.load(level),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        _body(context, state, notifier),
      ],
    );
  }

  Widget _body(BuildContext context, SummaryState state, SummaryNotifier notifier) {
    final theme = Theme.of(context);
    final data = state.data;

    // Show error state with retry.
    if (data is AsyncError) {
      return ErrorView(failure: data.error ?? 'Unknown error', onRetry: notifier.load);
    }

    // Not generated yet: explicit affordance instead of auto-fetching.
    if (!data.hasValue && !data.isLoading) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Get an AI-generated summary of this paper at four reading levels.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => notifier.load(),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Summarize this paper'),
              ),
            ],
          ),
        ),
      );
    }

    return data.when(
      skipLoadingOnReload: true,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => ErrorView(failure: e, onRetry: notifier.load),
      data: (summary) => _summary(context, summary),
    );
  }

  Widget _summary(BuildContext context, PaperSummaryAI s) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tldr.isNotEmpty ? s.tldr : 'No TL;DR available.',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (s.cacheHit) Icon(Icons.bolt, size: 16, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Based on ${s.grounding.basedOn.replaceAll('_', ' ')}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (s.sections.simpleExplanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(title: 'In simple terms', body: s.sections.simpleExplanation),
            ],
            if (s.sections.keyFindings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Key findings', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final f in s.sections.keyFindings)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Icon(Icons.circle, size: 5, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
            ],
            if (s.sections.methodology.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(title: 'Methodology', body: s.sections.methodology),
            ],
            if (s.sections.results.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Section(title: 'Results', body: s.sections.results),
            ],
            if (s.sections.limitations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Limitations', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final l in s.sections.limitations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('· $l', style: theme.textTheme.bodyMedium),
                ),
            ],
            if (s.sections.whyItMatters.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Why it matters', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(s.sections.whyItMatters, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        SelectableText(body, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
