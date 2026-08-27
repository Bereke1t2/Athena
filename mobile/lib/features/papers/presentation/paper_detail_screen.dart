import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/prefs/saved_papers.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai/presentation/paper_summary_card.dart';
import '../domain/paper.dart';
import '../domain/pdf_repository.dart';
import 'paper_detail_notifier.dart';

class PaperDetailScreen extends ConsumerWidget {
  const PaperDetailScreen({super.key, required this.id});

  final String id;

  String? _pdfUrl(PaperDetail paper) => resolvePdfUrl(paper);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paperDetailControllerProvider(id));
    final theme = Theme.of(context);
    final paper = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(paper?.summary.venueName ?? 'Paper'),
        actions: [
          if (paper != null)
            _SaveButton(
              savedPaper: SavedPaper(
                id: paper.summary.id,
                title: paper.title,
                venue: paper.summary.venueName,
                year: paper.summary.year,
                citedByCount: paper.summary.citedByCount,
                savedAt: DateTime.now(),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          failure: e,
          onRetry: () => ref.invalidate(paperDetailControllerProvider(id)),
        ),
        data: (paper) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // ---- header -------------------------------------------------
            Text(
              paper.title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700, height: 1.25),
            ),
            const SizedBox(height: 10),
            if (paper.authors.isNotEmpty)
              Text(
                paper.authors.map((a) => a.name).join(', '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            const SizedBox(height: 12),
            _metaChips(context, paper),
            const SizedBox(height: 16),

            // ---- actions ------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _pdfUrl(paper) == null ? null : () => _openPdf(context, paper),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Read PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/papers/${paper.summary.id}/chat'
                      '?title=${Uri.encodeComponent(paper.title)}',
                    ),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text('Chat'),
                  ),
                ),
              ],
            ),

            // ---- abstract ----------------------------------------------
            if ((paper.summary.abstract ?? '').isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionCard(
                icon: Icons.subject_rounded,
                title: 'Abstract',
                child: SelectableText(
                  paper.summary.abstract!,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
              ),
            ],

            // ---- AI summary --------------------------------------------
            const SizedBox(height: 20),
            PaperSummaryCard(paperId: paper.summary.id),

            // ---- topics -------------------------------------------------
            if (paper.topics.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionCard(
                icon: Icons.label_outline,
                title: 'Topics',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in paper.topics)
                      ActionChip(
                        label: Text(t.name),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => context.push('/topics/${t.slug}'),
                      ),
                  ],
                ),
              ),
            ],

            // ---- metadata ----------------------------------------------
            const SizedBox(height: 20),
            _SectionCard(
              icon: Icons.info_outline,
              title: 'Details',
              child: _details(context, paper),
            ),
          ],
        ),
      ),
    );
  }

  void _openPdf(BuildContext context, PaperDetail paper) {
    final url = _pdfUrl(paper)!;
    context.push('/papers/${paper.summary.id}/pdf'
        '?url=${Uri.encodeComponent(url)}'
        '&title=${Uri.encodeComponent(paper.title)}');
  }

  Widget _metaChips(BuildContext context, PaperDetail paper) {
    final theme = Theme.of(context);
    final parts = <(IconData, String)>[
      if (paper.summary.publishedOn != null)
        (
          Icons.calendar_today_outlined,
          MaterialLocalizations.of(context).formatYear(paper.summary.publishedOn!)
        ),
      (Icons.format_quote, '${paper.summary.citedByCount} citations'),
      (Icons.rule, '${paper.referenceCount} references'),
      if (paper.summary.isOpenAccess) (Icons.lock_open, 'Open access'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (icon, label) in parts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: theme.colorScheme.outline),
                const SizedBox(width: 5),
                Text(label, style: theme.textTheme.labelMedium),
              ],
            ),
          ),
      ],
    );
  }

  Widget _details(BuildContext context, PaperDetail paper) {
    final rows = <(String, String)>[
      ('Publication type', paper.summary.publicationType.replaceAll('_', ' ')),
      ('OA status', paper.summary.oaStatus.replaceAll('_', ' ')),
      if (paper.doi.isNotEmpty) ('DOI', paper.doi),
      if (paper.arxivId.isNotEmpty) ('arXiv', paper.arxivId),
      if (paper.language.isNotEmpty) ('Language', paper.language),
      if (paper.sources.isNotEmpty) ('Sources', paper.sources.join(', ')),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    rows[i].$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ),
                Expanded(
                  child: SelectableText(rows[i].$2,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1)
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ],
      ],
    );
  }
}

/// Bookmark toggle reflecting the local reading list.
class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.savedPaper});

  final SavedPaper savedPaper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPapersProvider);
    final notifier = ref.read(savedPapersProvider.notifier);
    final isSaved = saved.any((p) => p.id == savedPaper.id);

    return IconButton(
      tooltip: isSaved ? 'Remove from saved' : 'Save for later',
      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
      onPressed: () {
        notifier.toggle(savedPaper);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(isSaved ? 'Removed from saved' : 'Saved to your library'),
            duration: const Duration(seconds: 2),
          ));
      },
    );
  }
}

/// Titled content section with an icon header — the detail page's basic
/// building block so sections separate clearly.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
