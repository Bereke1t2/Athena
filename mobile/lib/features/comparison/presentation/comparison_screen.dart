import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di.dart';
import '../../../core/prefs/saved_papers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/comparison_models.dart';

class ComparisonScreen extends ConsumerStatefulWidget {
  const ComparisonScreen({super.key, this.initialPaperIds = const []});

  final List<String> initialPaperIds;

  @override
  ConsumerState<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends ConsumerState<ComparisonScreen> {
  late List<String> _paperIds;
  Future<ComparisonReport>? _reportFuture;

  @override
  void initState() {
    super.initState();
    _paperIds = List.from(widget.initialPaperIds);
    _triggerComparison();
  }

  void _triggerComparison() {
    if (_paperIds.length >= 2) {
      final repo = ref.read(comparisonRepositoryProvider);
      setState(() {
        _reportFuture = repo.comparePapers(_paperIds);
      });
    } else {
      setState(() {
        _reportFuture = null;
      });
    }
  }

  void _addPaperId(String id) {
    if (!_paperIds.contains(id) && _paperIds.length < 4) {
      setState(() {
        _paperIds.add(id);
      });
      _triggerComparison();
    }
  }

  void _removePaperId(String id) {
    setState(() {
      _paperIds.remove(id);
    });
    _triggerComparison();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'PAPER COMPARISON',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_paperIds.length < 4)
            IconButton(
              tooltip: 'Add Paper to Compare',
              icon: const Icon(Icons.add_rounded, size: 22),
              onPressed: () => _showAddPaperDialog(context),
            ),
        ],
      ),
      body: _paperIds.length < 2
          ? _buildInsufficientPapersView(context)
          : FutureBuilder<ComparisonReport>(
              future: _reportFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingView(context);
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    failure: snapshot.error!,
                    onRetry: _triggerComparison,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: Text('No comparison available'));
                }
                return _buildComparisonReport(context, snapshot.data!);
              },
            ),
    );
  }

  Widget _buildLoadingView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.canaryYellow),
            const SizedBox(height: 24),
            Text(
              'Synthesizing Comparison Matrix',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF141416),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyzing methodology, findings, consensus, and divergences across ${_paperIds.length} papers...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsufficientPapersView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = ref.watch(savedPapersProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  size: 32,
                  color: AppTheme.canaryYellow,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select Papers to Compare',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF141416),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose at least 2 papers (up to 4) to generate an AI comparative matrix, finding consensus points and methodological divergences.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (saved.isNotEmpty) ...[
          Text(
            'SAVED PAPERS FOR COMPARISON',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          for (final p in saved) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161922) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _paperIds.contains(p.id)
                      ? AppTheme.canaryYellow
                      : (isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB)),
                  width: _paperIds.contains(p.id) ? 1.5 : 1.0,
                ),
              ),
              child: ListTile(
                title: Text(
                  p.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${p.venue.isNotEmpty ? p.venue : "arXiv"} · ${p.year > 0 ? p.year : "Recent"}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    _paperIds.contains(p.id)
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    color: _paperIds.contains(p.id)
                        ? AppTheme.canaryYellow
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  ),
                  onPressed: () {
                    if (_paperIds.contains(p.id)) {
                      _removePaperId(p.id);
                    } else {
                      _addPaperId(p.id);
                    }
                  },
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildComparisonReport(BuildContext context, ComparisonReport report) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Meta header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${report.papers.length} PAPERS COMPARED',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.canaryYellow,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E222D) : const Color(0xFFEFF2F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.grounding == 'abstract+full_text' ? 'Full Text Grounded' : 'Abstract Grounded',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Regenerate Analysis',
              onPressed: _triggerComparison,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Comparative Synthesis Card
        _SynthesisCard(
          title: 'Comparative Executive Synthesis',
          summary: report.comparativeSummary,
          isDark: isDark,
        ),
        const SizedBox(height: 14),

        // Consensus & Divergence Cards
        if (report.consensusPoints.isNotEmpty) ...[
          _PointListCard(
            title: 'Key Consensus & Shared Findings',
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF10B981),
            points: report.consensusPoints,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
        ],

        if (report.divergencePoints.isNotEmpty) ...[
          _PointListCard(
            title: 'Divergence & Conflicting Perspectives',
            icon: Icons.call_split_rounded,
            iconColor: const Color(0xFFF59E0B),
            points: report.divergencePoints,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
        ],

        // Side-by-Side Matrix Header
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Text(
            'PAPERS ATTRIBUTE MATRIX',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ),

        // Side-by-Side Matrix Cards
        for (final item in report.papers) ...[
          _PaperMatrixCard(
            item: item,
            isDark: isDark,
            onRemove: report.papers.length > 2 ? () => _removePaperId(item.paperId) : null,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  void _showAddPaperDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saved = ref.read(savedPapersProvider);
    final available = saved.where((p) => !_paperIds.contains(p.id)).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Add Paper to Comparison',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                if (available.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No additional saved papers available. Save papers to your library to easily compare them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: available.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final p = available[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          tileColor: isDark ? const Color(0xFF101216) : const Color(0xFFF3F4F6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          trailing: const Icon(Icons.add_circle_outline_rounded, size: 20),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addPaperId(p.id);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SynthesisCard extends StatelessWidget {
  const _SynthesisCard({
    required this.title,
    required this.summary,
    required this.isDark,
  });

  final String title;
  final String summary;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.canaryYellow),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            summary,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointListCard extends StatelessWidget {
  const _PointListCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.points,
    required this.isDark,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final List<String> points;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final pt in points) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      pt,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaperMatrixCard extends StatelessWidget {
  const _PaperMatrixCard({
    required this.item,
    required this.isDark,
    this.onRemove,
  });

  final ComparisonMatrixItem item;
  final bool isDark;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and Remove
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => context.push('/papers/${item.paperId}'),
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                          color: isDark ? Colors.white : const Color(0xFF141416),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.venue.isNotEmpty ? item.venue : "arXiv"} · ${item.year > 0 ? item.year : "Recent"}${item.authors.isNotEmpty ? " · ${item.authors.join(', ')}" : ""}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Remove from comparison',
                  onPressed: onRemove,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Key Takeaway
          if (item.keyTakeaway.isNotEmpty) ...[
            _AttributeBlock(
              label: 'Key Takeaway',
              content: item.keyTakeaway,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Methodology
          if (item.methodology.isNotEmpty) ...[
            _AttributeBlock(
              label: 'Methodology',
              content: item.methodology,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Strengths
          if (item.strengths.isNotEmpty) ...[
            _BulletBlock(
              label: 'Strengths',
              color: const Color(0xFF10B981),
              items: item.strengths,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
          ],

          // Limitations
          if (item.limitations.isNotEmpty) ...[
            _BulletBlock(
              label: 'Limitations',
              color: const Color(0xFFEF4444),
              items: item.limitations,
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttributeBlock extends StatelessWidget {
  const _AttributeBlock({
    required this.label,
    required this.content,
    required this.isDark,
  });

  final String label;
  final String content;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

class _BulletBlock extends StatelessWidget {
  const _BulletBlock({
    required this.label,
    required this.color,
    required this.items,
    required this.isDark,
  });

  final String label;
  final Color color;
  final List<String> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        for (final it in items) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 6),
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ),
                Expanded(
                  child: Text(
                    it,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
