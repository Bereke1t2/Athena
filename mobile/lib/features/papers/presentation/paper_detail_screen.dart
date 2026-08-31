import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/prefs/saved_papers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai/presentation/paper_summary_card.dart';
import '../domain/paper.dart';
import '../domain/pdf_repository.dart';
import 'paper_detail_notifier.dart';

class PaperDetailScreen extends ConsumerWidget {
  const PaperDetailScreen({super.key, required this.id});

  final String id;

  String? _pdfUrl(PaperDetail paper) => resolvePdfUrl(paper);
  String? _webUrl(PaperDetail paper) => resolveWebUrl(paper);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paperDetailControllerProvider(id));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paper = async.valueOrNull;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'PAPER DETAILS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copied to clipboard')),
              );
            },
          ),
          if (paper != null) ...[
            IconButton(
              tooltip: _pdfUrl(paper) != null ? 'Open PDF' : 'Read Article',
              icon: Icon(
                _pdfUrl(paper) != null ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
                size: 20,
              ),
              onPressed: () {
                final pdf = _pdfUrl(paper);
                if (pdf != null) {
                  _openPdf(context, paper);
                } else {
                  _openReader(context, paper);
                }
              },
            ),
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
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          failure: e,
          onRetry: () => ref.invalidate(paperDetailControllerProvider(id)),
        ),
        data: (paper) {
          final pdfUrl = _pdfUrl(paper);
          final webUrl = _webUrl(paper);

          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                children: [
                  // Paper Title
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 50),
                    child: Text(
                      paper.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                        fontSize: 22,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF141416),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Real Authors Row
                  if (paper.authors.isNotEmpty)
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 80),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final a in paper.authors)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E222D) : const Color(0xFFEFF2F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 13,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    a.name,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Publication Venue & Year Row
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paper.summary.venueName.isNotEmpty ? paper.summary.venueName : 'arXiv',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.canaryYellow,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${paper.summary.year > 0 ? paper.summary.year : "Recent"} · ${paper.summary.publicationType.replaceAll('_', ' ')}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3 Key Metrics Row (Research metrics)
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 120),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161922) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF282D3B) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            value: '${paper.summary.citedByCount}',
                            label: 'citations',
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                          ),
                          _StatItem(
                            value: '${paper.referenceCount}',
                            label: 'references',
                            isDark: isDark,
                          ),
                          Container(
                            width: 1,
                            height: 28,
                            color: isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB),
                          ),
                          _StatItem(
                            value: paper.summary.isOpenAccess ? 'Open Access' : 'Preprint',
                            label: 'access tier',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Action Buttons Strip
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 140),
                    child: Row(
                      children: [
                        if (pdfUrl != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                foregroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _openPdf(context, paper),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                              label: const Text(
                                'Open PDF',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          )
                        else if (webUrl != null)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                foregroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () => _openWeb(context, webUrl),
                              icon: const Icon(Icons.language_rounded, size: 16),
                              label: const Text(
                                'Open Web',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        if (pdfUrl != null || webUrl != null) const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF373D4E) : const Color(0xFFD1D5DB),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              context.push(
                                '/papers/${paper.summary.id}/chat?title=${Uri.encodeComponent(paper.title)}',
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text(
                              'Ask Paper AI',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Abstract Section
                  if ((paper.summary.abstract ?? '').isNotEmpty) ...[
                    _SectionCard(
                      icon: Icons.subject_rounded,
                      title: 'Abstract',
                      child: SelectableText(
                        paper.summary.abstract!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          fontSize: 13.5,
                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // AI Research Summary Block
                  PaperSummaryCard(paperId: paper.summary.id),

                  const SizedBox(height: 18),

                  // Real Topics & Taxonomy
                  if (paper.topics.isNotEmpty) ...[
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FIELDS & TOPICS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final t in paper.topics)
                                InkWell(
                                  onTap: () => context.push('/topics/${t.slug}'),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF161922) : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.label_outline_rounded,
                                          size: 12,
                                          color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          t.name,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Real Publication Identifiers & Sources
                  _SectionCard(
                    icon: Icons.info_outline,
                    title: 'Publication Identifiers',
                    child: _details(context, paper),
                  ),
                ],
              ),

              // Bottom Sticky Action Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF101216) : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (pdfUrl != null) ...[
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                foregroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(23),
                                ),
                              ),
                              onPressed: () => _openPdf(context, paper),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                              label: const Text(
                                'Open PDF',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                                foregroundColor: isDark ? const Color(0xFF141416) : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(23),
                                ),
                              ),
                              onPressed: () => _openReader(context, paper),
                              icon: const Icon(Icons.menu_book_rounded, size: 16),
                              label: const Text(
                                'Read Article',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23),
                              ),
                            ),
                            onPressed: () {
                              context.push(
                                '/papers/${paper.summary.id}/chat?title=${Uri.encodeComponent(paper.title)}',
                              );
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text(
                              'Ask AI',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openReader(BuildContext context, PaperDetail paper) {
    final encodedTitle = Uri.encodeComponent(paper.title);
    context.push('/papers/${paper.summary.id}/reader?title=$encodedTitle');
  }

  void _openPdf(BuildContext context, PaperDetail paper) {
    final url = _pdfUrl(paper)!;
    context.push('/papers/${paper.summary.id}/pdf'
        '?url=${Uri.encodeComponent(url)}'
        '&title=${Uri.encodeComponent(paper.title)}');
  }

  Future<void> _openWeb(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link URL')),
      );
      return;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link in a browser')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link in a browser')),
        );
      }
    }
  }

  Widget _details(BuildContext context, PaperDetail paper) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doiUrl = paper.doi.isNotEmpty
        ? (paper.doi.startsWith('http') ? paper.doi : 'https://doi.org/${paper.doi}')
        : null;
    final arxivUrl = paper.arxivId.isNotEmpty ? 'https://arxiv.org/abs/${paper.arxivId}' : null;

    final rows = <(String, String, String?)>[
      ('Publication type', paper.summary.publicationType.replaceAll('_', ' '), null),
      ('OA status', paper.summary.oaStatus.replaceAll('_', ' '), null),
      if (paper.doi.isNotEmpty) ('DOI', paper.doi, doiUrl),
      if (paper.arxivId.isNotEmpty) ('arXiv', paper.arxivId, arxivUrl),
      if (paper.language.isNotEmpty) ('Language', paper.language, null),
      if (paper.sources.isNotEmpty) ('Sources', paper.sources.join(', '), null),
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
                  width: 120,
                  child: Text(
                    rows[i].$1,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: rows[i].$3 != null
                      ? InkWell(
                          onTap: () => _openWeb(context, rows[i].$3!),
                          child: Text(
                            rows[i].$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      : SelectableText(
                          rows[i].$2,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
          if (i < rows.length - 1)
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.isDark,
  });

  final String value;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF141416),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

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
      icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 20),
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
                Icon(icon, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

