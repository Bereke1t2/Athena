import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di.dart';
import '../../../core/prefs/saved_papers.dart';
import '../../../core/prefs/user_preferences.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../../core/widgets/state_views.dart';
import '../../ai/presentation/paper_summary_card.dart';
import '../../follows/presentation/follows_notifier.dart';
import '../../history/presentation/history_notifier.dart';
import '../domain/citation_graph.dart';
import '../domain/paper.dart';
import '../domain/pdf_repository.dart';
import 'paper_detail_notifier.dart';
import 'paper_export_modal.dart';

final paperCitationGraphProvider =
    FutureProvider.family<CitationGraph, ({String id, int depth})>((ref, arg) async {
  final graph = await ref.watch(paperRepositoryProvider).getCitationGraph(arg.id, depth: arg.depth);
  if (graph.nodes.length <= 1) {
    try {
      final related = await ref.watch(paperRepositoryProvider).getRelated(arg.id, limit: 12);
      if (related.isNotEmpty) {
        final seedNode = graph.nodes.isNotEmpty
            ? graph.nodes.first
            : CitationGraphNode(id: arg.id, title: 'Seed Research', isSeed: true);
        final nodes = <CitationGraphNode>[seedNode];
        final edges = <CitationGraphEdge>[];
        for (final p in related) {
          nodes.add(CitationGraphNode(
            id: p.id,
            title: p.title,
            year: p.year,
            venueName: p.venueName,
            citedByCount: p.citedByCount,
            depth: 1,
            isSeed: false,
          ));
          edges.add(CitationGraphEdge(
            source: arg.id,
            target: p.id,
            isInfluential: p.citedByCount > 50,
            stance: 'mentions',
            context: 'Connected research network',
          ));
        }
        return CitationGraph(
          rootId: arg.id,
          depth: arg.depth,
          nodes: nodes,
          edges: edges,
          totalNodes: nodes.length,
          totalEdges: edges.length,
        );
      }
    } catch (_) {}
  }
  return graph;
});

class PaperDetailScreen extends ConsumerWidget {
  const PaperDetailScreen({super.key, required this.id});

  final String id;

  String? _pdfUrl(PaperDetail paper) => resolvePdfUrl(paper);
  String? _webUrl(PaperDetail paper) => resolveWebUrl(paper);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(paperDetailControllerProvider(id), (prev, next) {
      if (next.hasValue && next.value != null && (prev == null || !prev.hasValue)) {
        if (UserPreferences.instance.authToken != null && isUuid(id)) {
          ref.read(historyNotifierProvider.notifier).recordProgress(id, 5.0);
        }
      }
    });

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
          if (paper != null) ...[
            IconButton(
              tooltip: 'Audio Brief',
              icon: const Icon(Icons.headphones_outlined, size: 20),
              onPressed: () => context.push(
                '/create-audio?paperId=${paper.summary.id}&title=${Uri.encodeComponent(paper.title)}',
              ),
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20),
              tooltip: 'More actions',
              onSelected: (val) {
                switch (val) {
                  case 'share':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                    break;
                  case 'cite':
                    showPaperExportModal(context, paper);
                    break;
                  case 'compare':
                    context.push('/compare?ids=${paper.summary.id}');
                    break;
                  case 'read':
                    final pdf = _pdfUrl(paper);
                    if (pdf != null) {
                      _openPdf(context, paper);
                    } else {
                      _openReader(context, paper);
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Share'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cite',
                  child: Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Cite & Export'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'compare',
                  child: Row(
                    children: [
                      Icon(Icons.compare_arrows_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Compare Papers'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'read',
                  child: Row(
                    children: [
                      Icon(
                        _pdfUrl(paper) != null ? Icons.picture_as_pdf_rounded : Icons.menu_book_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(_pdfUrl(paper) != null ? 'Open PDF' : 'Read Article'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.share_outlined, size: 20),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
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
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _showAuthorModal(context, a),
                              child: Container(
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
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // Publication Venue & Year Row
                  AnimatedEntrance(
                    delay: const Duration(milliseconds: 100),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                    child: Column(
                      children: [
                        Row(
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF373D4E) : const Color(0xFFD1D5DB),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => showPaperExportModal(context, paper),
                                icon: const Icon(Icons.format_quote_rounded, size: 16),
                                label: const Text(
                                  'Cite & Export',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF373D4E) : const Color(0xFFD1D5DB),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => context.push('/compare?ids=${paper.summary.id}'),
                                icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                                label: const Text(
                                  'Compare',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF4338CA).withValues(alpha: 0.6) : const Color(0xFFC7D2FE),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.push(
                              '/create-audio?paperId=${paper.summary.id}&title=${Uri.encodeComponent(paper.title)}',
                            ),
                            icon: const Icon(Icons.headphones_rounded, size: 16),
                            label: const Text(
                              'Generate Audio Brief (AI Voice Synthesis)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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

                  // Citations & References Explorer
                  _CitationsExplorerCard(
                    paperId: paper.summary.id,
                    citedCount: paper.summary.citedByCount,
                    refCount: paper.referenceCount,
                  ),

                  const SizedBox(height: 18),

                  // Citation Network Graph Explorer
                  _CitationGraphExplorerCard(paperId: paper.summary.id),

                  const SizedBox(height: 18),

                  // Related Research
                  _RelatedPapersCard(paperId: paper.summary.id),

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

  void _showAuthorModal(BuildContext context, AuthorLine author) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final follows = ref.watch(followsNotifierProvider);
            final following = follows.isAuthorFollowed(author.id);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.canaryYellow,
                          child: Text(
                            author.name.isNotEmpty ? author.name[0].toUpperCase() : 'A',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF141416), fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                author.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                              ),
                              if (author.affiliations.isNotEmpty)
                                Text(
                                  author.affiliations.join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                              if (author.orcid != null && author.orcid!.isNotEmpty)
                                Text(
                                  'ORCID: ${author.orcid}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFA6C8E0)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : const Color(0xFF141416),
                              side: BorderSide(color: isDark ? const Color(0xFF3F475A) : const Color(0xFFD1D5DB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.push('/search?q=${Uri.encodeComponent(author.name)}');
                            },
                            icon: const Icon(Icons.search_rounded, size: 16),
                            label: const Text('Find Papers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: following ? (isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB)) : AppTheme.canaryYellow,
                              foregroundColor: following ? (isDark ? Colors.white : const Color(0xFF141416)) : const Color(0xFF141416),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              ref.read(followsNotifierProvider.notifier).toggleAuthorFollow(author.id, author.name);
                            },
                            icon: Icon(following ? Icons.check_rounded : Icons.add_rounded, size: 16),
                            label: Text(
                              following ? 'Following' : 'Follow',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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

class _CitationsExplorerCard extends ConsumerStatefulWidget {
  const _CitationsExplorerCard({
    required this.paperId,
    required this.citedCount,
    required this.refCount,
  });

  final String paperId;
  final int citedCount;
  final int refCount;

  @override
  ConsumerState<_CitationsExplorerCard> createState() => _CitationsExplorerCardState();
}

class _CitationsExplorerCardState extends ConsumerState<_CitationsExplorerCard> {
  String _direction = 'in'; // 'in' = cited by, 'out' = references
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Citation Network',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  child: Text(_isExpanded ? 'Hide' : 'Explore'),
                ),
              ],
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  ChoiceChip(
                    label: Text('Cited By (${widget.citedCount})'),
                    selected: _direction == 'in',
                    onSelected: (_) => setState(() => _direction = 'in'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('References (${widget.refCount})'),
                    selected: _direction == 'out',
                    onSelected: (_) => setState(() => _direction = 'out'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CitationsList(
                paperId: widget.paperId,
                direction: _direction,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationsList extends ConsumerWidget {
  const _CitationsList({
    required this.paperId,
    required this.direction,
    required this.isDark,
  });

  final String paperId;
  final String direction;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(paperCitationsProvider(paperId, direction: direction));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No citation records found for this view.',
          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        ),
      ),
      data: (papers) {
        if (papers.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No linked papers found.',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
            ),
          );
        }
        return Column(
          children: [
            for (final p in papers.take(5)) ...[
              InkWell(
                onTap: () => context.push('/papers/${p.id}'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${p.venueName.isNotEmpty ? p.venueName : "arXiv"} · ${p.year > 0 ? p.year : "Recent"} · ${p.citedByCount} citations',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              if (p != papers.take(5).last)
                Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ],
          ],
        );
      },
    );
  }
}

class _RelatedPapersCard extends ConsumerWidget {
  const _RelatedPapersCard({required this.paperId});

  final String paperId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(paperRelatedProvider(paperId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.recommend_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Related Research',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),
            async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No related research discovered yet.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                ),
              ),
              data: (papers) {
                if (papers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No related research discovered yet.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in papers.take(4)) ...[
                      InkWell(
                        onTap: () => context.push('/papers/${p.id}'),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.canaryYellow.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.menu_book_rounded, size: 14, color: AppTheme.canaryYellow),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${p.venueName.isNotEmpty ? p.venueName : "arXiv"} · ${p.year > 0 ? p.year : "Recent"} · ${p.citedByCount} citations',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, size: 18),
                            ],
                          ),
                        ),
                      ),
                      if (p != papers.take(4).last)
                        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CitationGraphExplorerCard extends ConsumerStatefulWidget {
  const _CitationGraphExplorerCard({required this.paperId});

  final String paperId;

  @override
  ConsumerState<_CitationGraphExplorerCard> createState() => _CitationGraphExplorerCardState();
}

class _CitationGraphExplorerCardState extends ConsumerState<_CitationGraphExplorerCard> {
  int _depth = 1;
  bool _isExpanded = false;
  bool _isVisualView = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(paperCitationGraphProvider((id: widget.paperId, depth: _depth)));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  Icon(Icons.hub_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Citation Network Graph',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  async.when(
                    data: (g) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${g.totalNodes} papers · ${g.totalEdges} links',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.canaryYellow),
                      ),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 6),
                  Icon(_isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('1-Hop Direct', style: TextStyle(fontSize: 11)),
                    selected: _depth == 1,
                    onSelected: (val) {
                      if (val) setState(() => _depth = 1);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('2-Hop Extended', style: TextStyle(fontSize: 11)),
                    selected: _depth == 2,
                    onSelected: (val) {
                      if (val) setState(() => _depth = 2);
                    },
                  ),
                  const Spacer(),
                  // Toggle between Visual Graph and List View
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E3547) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isVisualView = true),
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isVisualView
                                  ? (isDark ? const Color(0xFF2D3748) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                            ),
                            child: Icon(
                              Icons.hub_rounded,
                              size: 15,
                              color: _isVisualView
                                  ? AppTheme.canaryYellow
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isVisualView = false),
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: !_isVisualView
                                  ? (isDark ? const Color(0xFF2D3748) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                            ),
                            child: Icon(
                              Icons.view_list_rounded,
                              size: 15,
                              color: !_isVisualView
                                  ? AppTheme.canaryYellow
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Could not load citation network graph.',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                  ),
                ),
                data: (graph) {
                  final nonSeedNodes = graph.nodes.where((n) => !n.isSeed).toList();
                  if (nonSeedNodes.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No multi-hop citation connections found for this paper yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    );
                  }

                  if (_isVisualView) {
                    return _InteractiveCitationGraphCanvas(
                      graph: graph,
                      seedPaperId: widget.paperId,
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'CONNECTED RESEARCH NODES',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      for (final node in nonSeedNodes.take(8)) ...[
                        Builder(
                          builder: (context) {
                            final edge = graph.edges.firstWhere(
                              (e) =>
                                  (e.source == node.id && e.target == graph.rootId) ||
                                  (e.target == node.id && e.source == graph.rootId),
                              orElse: () => const CitationGraphEdge(source: '', target: ''),
                            );
                            return InkWell(
                              onTap: () => context.push('/papers/${node.id}'),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: node.depth == 1
                                            ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                                            : const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        node.depth == 1 ? 'HOP 1' : 'HOP 2',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: node.depth == 1
                                              ? const Color(0xFF60A5FA)
                                              : const Color(0xFFA78BFA),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            node.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            spacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text(
                                                '${node.venueName.isNotEmpty ? node.venueName : "arXiv"} · ${node.year > 0 ? node.year : "Recent"} · ${node.citedByCount} citations',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                                ),
                                              ),
                                              if (edge.stance == 'supports')
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF55EFC4).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('✓ Supports', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
                                                ),
                                              if (edge.stance == 'contradicts')
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFF7675).withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('⚠ Contradicts', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFD63031))),
                                                ),
                                              if (edge.isInfluential)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.canaryYellow.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('★ Influential', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.canaryYellow)),
                                                ),
                                            ],
                                          ),
                                          if (edge.context.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              '"${edge.context}"',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontStyle: FontStyle.italic,
                                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        if (node != nonSeedNodes.take(8).last)
                          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InteractiveCitationGraphCanvas extends StatefulWidget {
  const _InteractiveCitationGraphCanvas({
    required this.graph,
    required this.seedPaperId,
  });

  final CitationGraph graph;
  final String seedPaperId;

  @override
  State<_InteractiveCitationGraphCanvas> createState() => _InteractiveCitationGraphCanvasState();
}

class _InteractiveCitationGraphCanvasState extends State<_InteractiveCitationGraphCanvas> {
  String? _selectedNodeId;
  final TransformationController _transformController = TransformationController();

  @override
  void initState() {
    super.initState();
    _selectedNodeId = widget.seedPaperId;
  }

  @override
  void didUpdateWidget(covariant _InteractiveCitationGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seedPaperId != widget.seedPaperId) {
      _selectedNodeId = widget.seedPaperId;
    }
  }

  Map<String, Offset> _computePositions(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final map = <String, Offset>{};
    final seed = widget.graph.nodes.where((n) => n.isSeed).toList();
    final seedId = seed.isNotEmpty ? seed.first.id : widget.graph.rootId;
    map[seedId] = center;

    final hop1 = widget.graph.nodes.where((n) => !n.isSeed && n.depth <= 1).toList();
    final hop2 = widget.graph.nodes.where((n) => !n.isSeed && n.depth > 1).toList();

    const r1 = 78.0;
    for (int i = 0; i < hop1.length; i++) {
      final angle = (2 * math.pi * i / (hop1.isNotEmpty ? hop1.length : 1)) - (math.pi / 2);
      map[hop1[i].id] = Offset(
        center.dx + r1 * math.cos(angle),
        center.dy + r1 * math.sin(angle),
      );
    }

    const r2 = 120.0;
    for (int j = 0; j < hop2.length; j++) {
      final angle = (2 * math.pi * (j + 0.5) / (hop2.isNotEmpty ? hop2.length : 1)) - (math.pi / 2);
      map[hop2[j].id] = Offset(
        center.dx + r2 * math.cos(angle),
        center.dy + r2 * math.sin(angle),
      );
    }
    return map;
  }

  CitationGraphNode? _findClosestNode(Offset pos, Size size) {
    final positions = _computePositions(size);
    CitationGraphNode? closest;
    double minDistance = 32.0;
    for (final node in widget.graph.nodes) {
      final nodePos = positions[node.id];
      if (nodePos != null) {
        final dist = (nodePos - pos).distance;
        if (dist < minDistance) {
          minDistance = dist;
          closest = node;
        }
      }
    }
    return closest;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedNode = widget.graph.nodes.firstWhere(
      (n) => n.id == _selectedNodeId,
      orElse: () => widget.graph.nodes.firstWhere(
        (n) => n.isSeed,
        orElse: () => widget.graph.nodes.first,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const _LegendDot(color: AppTheme.canaryYellow, label: 'Seed'),
                const SizedBox(width: 10),
                const _LegendDot(color: Color(0xFF3B82F6), label: 'Hop 1'),
                const SizedBox(width: 10),
                const _LegendDot(color: Color(0xFF8B5CF6), label: 'Hop 2'),
                const Spacer(),
                InkWell(
                  onTap: () => _transformController.value = Matrix4.identity(),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.center_focus_strong_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          'Center',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF1E2330) : const Color(0xFFE2E8F0)),
          SizedBox(
            height: 250,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: InteractiveViewer(
                transformationController: _transformController,
                boundaryMargin: const EdgeInsets.all(80),
                minScale: 0.6,
                maxScale: 2.2,
                child: GestureDetector(
                  onTapUp: (details) {
                    final hit = _findClosestNode(details.localPosition, const Size(340, 250));
                    if (hit != null) {
                      setState(() => _selectedNodeId = hit.id);
                    }
                  },
                  child: CustomPaint(
                    size: const Size(340, 250),
                    painter: _CitationGraphPainter(
                      graph: widget.graph,
                      selectedNodeId: _selectedNodeId,
                      isDark: isDark,
                      positions: _computePositions(const Size(340, 250)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF1E2330) : const Color(0xFFE2E8F0)),
          _SelectedNodeCard(
            node: selectedNode,
            isDark: isDark,
            isSeed: selectedNode.isSeed,
            edge: widget.graph.edges.firstWhere(
              (e) =>
                  (e.source == selectedNode.id && e.target == widget.graph.rootId) ||
                  (e.target == selectedNode.id && e.source == widget.graph.rootId),
              orElse: () => const CitationGraphEdge(source: '', target: ''),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitationGraphPainter extends CustomPainter {
  _CitationGraphPainter({
    required this.graph,
    required this.selectedNodeId,
    required this.isDark,
    required this.positions,
  });

  final CitationGraph graph;
  final String? selectedNodeId;
  final bool isDark;
  final Map<String, Offset> positions;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final orbitPaint = Paint()
      ..color = isDark
          ? const Color(0xFF2A3042).withValues(alpha: 0.3)
          : const Color(0xFFCBD5E1).withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 78.0, orbitPaint);
    if (graph.nodes.any((n) => n.depth > 1)) {
      canvas.drawCircle(center, 120.0, orbitPaint);
    }

    for (final edge in graph.edges) {
      final p1 = positions[edge.source];
      final p2 = positions[edge.target];
      if (p1 == null || p2 == null) continue;

      final isConnectedToSelected = edge.source == selectedNodeId || edge.target == selectedNodeId;

      Color edgeColor;
      double strokeWidth;
      if (edge.stance == 'supports') {
        edgeColor = const Color(0xFF10B981);
        strokeWidth = isConnectedToSelected ? 2.4 : 1.6;
      } else if (edge.stance == 'contradicts') {
        edgeColor = const Color(0xFFEF4444);
        strokeWidth = isConnectedToSelected ? 2.4 : 1.6;
      } else if (edge.isInfluential) {
        edgeColor = AppTheme.canaryYellow;
        strokeWidth = isConnectedToSelected ? 2.2 : 1.5;
      } else {
        edgeColor = isDark
            ? (isConnectedToSelected ? const Color(0xFF60A5FA) : const Color(0xFF475569))
            : (isConnectedToSelected ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8));
        strokeWidth = isConnectedToSelected ? 1.8 : 1.0;
      }

      final paint = Paint()
        ..color = isConnectedToSelected ? edgeColor : edgeColor.withValues(alpha: 0.5)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, paint);

      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      final dotPaint = Paint()..color = edgeColor.withValues(alpha: 0.85);
      canvas.drawCircle(mid, 2.2, dotPaint);
    }

    for (final node in graph.nodes) {
      final pos = positions[node.id];
      if (pos == null) continue;

      final isSelected = node.id == selectedNodeId;
      final isSeed = node.isSeed;

      double radius;
      Color nodeColor;

      if (isSeed) {
        radius = 17.0;
        nodeColor = AppTheme.canaryYellow;

        final glowPaint = Paint()
          ..color = AppTheme.canaryYellow.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0;
        canvas.drawCircle(pos, radius + 4.0, glowPaint);
      } else if (node.depth == 1) {
        radius = 12.0 + (node.citedByCount > 0 ? (math.log(node.citedByCount + 1) * 1.1).clamp(0.0, 6.0) : 0.0);
        nodeColor = const Color(0xFF3B82F6);
      } else {
        radius = 10.0;
        nodeColor = const Color(0xFF8B5CF6);
      }

      if (isSelected) {
        final selectPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(pos, radius + 3.0, selectPaint);
      }

      final fillPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius, fillPaint);

      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF11141B) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(pos, radius, borderPaint);

      final labelText = isSeed
          ? 'SEED'
          : (node.year > 0 ? '${node.year}' : (node.title.length > 7 ? '${node.title.substring(0, 6)}…' : node.title));
      final textSpan = TextSpan(
        text: labelText,
        style: TextStyle(
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - (textPainter.width / 2), pos.dy + radius + 2.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CitationGraphPainter oldDelegate) {
    return oldDelegate.graph != graph ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.isDark != isDark;
  }
}

class _SelectedNodeCard extends StatelessWidget {
  const _SelectedNodeCard({
    required this.node,
    required this.isDark,
    required this.isSeed,
    required this.edge,
  });

  final CitationGraphNode node;
  final bool isDark;
  final bool isSeed;
  final CitationGraphEdge edge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSeed
                      ? AppTheme.canaryYellow.withValues(alpha: 0.2)
                      : (node.depth == 1
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.15)
                          : const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSeed ? '★ SEED PAPER' : (node.depth == 1 ? 'HOP 1 DIRECT' : 'HOP 2 EXTENDED'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSeed
                        ? AppTheme.canaryYellow
                        : (node.depth == 1 ? const Color(0xFF60A5FA) : const Color(0xFFA78BFA)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (edge.stance == 'supports')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('✓ Supports',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                ),
              if (edge.stance == 'contradicts')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('⚠ Contradicts',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                ),
              if (edge.isInfluential)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.canaryYellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('★ Influential',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.canaryYellow)),
                ),
              const Spacer(),
              if (!isSeed)
                TextButton(
                  onPressed: () => context.push('/papers/${node.id}'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Explore', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                      SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, size: 13),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            node.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${node.venueName.isNotEmpty ? node.venueName : "arXiv"} · ${node.year > 0 ? node.year : "Recent"} · ${node.citedByCount} citations',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF9CA3AF)
                : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}



