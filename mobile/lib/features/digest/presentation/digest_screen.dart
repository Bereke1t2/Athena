import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/digest_models.dart';
import 'digest_notifier.dart';

class DigestScreen extends ConsumerWidget {
  const DigestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(digestNotifierProvider);
    final notifier = ref.read(digestNotifierProvider.notifier);
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.deepDark : AppTheme.lightBg,
      appBar: AthenaTopBar(
        title: 'Research Digest',
        showLeading: false,
        actions: [
          if (state.digest != null)
            AthenaCircularIconButton(
              icon: Icons.copy_all_rounded,
              tooltip: 'Copy Briefing',
              onPressed: () async {
                final md = formatDigestMarkdown(state.digest!);
                await Clipboard.setData(ClipboardData(text: md));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Research briefing copied to clipboard as Markdown.'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          AthenaCircularIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh Briefing',
            onPressed: state.isGenerating || state.isLoading
                ? null
                : () {
                    if (!authState.isAuthenticated) {
                      notifier.loadLatest();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Updated latest research briefing for your topics.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      notifier.regenerate();
                    }
                  },
          ),
        ],
      ),
      body: DotGridBackground(
        child: Builder(
          builder: (context) {
            if (state.isLoading && state.digest == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && state.digest == null) {
              return ErrorView(
                failure: state.error!,
                onRetry: () => notifier.loadLatest(),
              );
            }
            final digest = state.digest;
            if (digest == null) {
              return const EmptyView(
                icon: Icons.auto_stories_outlined,
                title: 'No digest generated yet',
                subtitle: 'Follow research topics to receive periodic briefings.',
              );
            }

            final totalPapers = digest.sections.fold<int>(0, (sum, sec) => sum + sec.papers.length);

            return RefreshIndicator(
              onRefresh: () => notifier.loadLatest(),
              color: AppTheme.coral,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Guest notice banner
                  if (!authState.isAuthenticated)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withValues(alpha: isDark ? 0.12 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.coral.withValues(alpha: isDark ? 0.3 : 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.coral, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notifier.followedTopics.isNotEmpty
                                      ? 'Tailored Research Briefing'
                                      : 'Trending Athena Briefing',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  notifier.followedTopics.isNotEmpty
                                      ? 'Personalized to ${notifier.followedTopics.length} followed topics. Sign in to enable push alerts.'
                                      : 'Follow topics to tailor weekly intelligence to your scientific focus.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.coral.withValues(alpha: 0.15),
                              foregroundColor: AppTheme.coral,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => context.push('/login'),
                            child: const Text('Sign In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ),

                  // Header Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E222D), const Color(0xFF151822)]
                            : [Colors.white, const Color(0xFFF9FAFC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.coral.withValues(alpha: isDark ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                digest.frequency.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.coral,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Text(
                              '${digest.generatedAt.day}/${digest.generatedAt.month}/${digest.generatedAt.year}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Weekly Research Briefing',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Recent breakthroughs, empirical discoveries, and key methodologies published this week across your topics.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // AI Weekly Executive Synthesis Card
                  if (digest.aiSummary.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181C26) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.coral.withValues(alpha: 0.35)
                              : AppTheme.coral.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.coral.withValues(alpha: isDark ? 0.08 : 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.coral.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.auto_awesome, color: AppTheme.coral, size: 16),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'ATHENA AI · WEEKLY RESEARCH SYNTHESIS',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: AppTheme.coral,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'GROUNDED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF10B981),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            digest.aiSummary,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.55,
                              color: isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1F2937),
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF232733) : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$totalPapers recent publications',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              ...digest.pulses.take(4).map((pulse) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.coral.withValues(alpha: isDark ? 0.12 : 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '#${pulse.topicSlug}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.coral,
                                      ),
                                    ),
                                  )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Takeaways Section
                  if (digest.topTakeaways.isNotEmpty) ...[
                    const _SectionTitle(title: 'KEY BREAKTHROUGHS & TAKEAWAYS'),
                    const SizedBox(height: 10),
                    ...digest.topTakeaways.map((takeaway) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF161922) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2, right: 10),
                                child: Icon(Icons.check_circle_outline_rounded,
                                    size: 18, color: Color(0xFF55EFC4)),
                              ),
                              Expanded(
                                child: Text(
                                  takeaway,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                  ],

                  // Topic Pulses Section
                  if (digest.pulses.isNotEmpty) ...[
                    const _SectionTitle(title: 'TOPIC VELOCITY & PULSE'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 136,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: digest.pulses.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final pulse = digest.pulses[i];
                          return Container(
                            width: 175,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF161922) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  pulse.topicName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.coral),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '+${pulse.velocity.toStringAsFixed(1)}x velocity',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.coral,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                // Trend sparkline graph
                                SizedBox(
                                  height: 22,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: _VelocitySparklinePainter(
                                      velocity: pulse.velocity,
                                      isDark: isDark,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${pulse.paperCount} recent papers',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Curated Sections
                  ...digest.sections.map((section) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionTitle(title: section.title.toUpperCase()),
                          const SizedBox(height: 4),
                          Text(
                            section.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...section.papers.map((paper) => Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => context.push('/papers/${paper.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          paper.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // Publication Date Badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF232733) : const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.calendar_today_outlined,
                                                      size: 11, color: AppTheme.coral),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _formatPublicationDate(paper.publishedOn, paper.year),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                paper.venueName.isNotEmpty ? paper.venueName : 'Preprint',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '${paper.citedByCount} citations',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF74B9FF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                          const SizedBox(height: 16),
                        ],
                      )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatPublicationDate(DateTime? date, int year) {
    if (date == null) return '$year';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = (date.month >= 1 && date.month <= 12) ? months[date.month - 1] : '';
    return '${date.day} $m ${date.year}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: isDark ? AppTheme.coral : const Color(0xFF111827),
      ),
    );
  }
}

class _VelocitySparklinePainter extends CustomPainter {
  const _VelocitySparklinePainter({required this.velocity, required this.isDark});

  final double velocity;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final path = Path();
    final h = size.height;
    final w = size.width;

    // Build trend curve based on velocity
    final vFactor = (velocity / 3.0).clamp(0.2, 1.2);
    final p0 = Offset(0, h * 0.85);
    final p1 = Offset(w * 0.35, h * (0.85 - (0.35 * vFactor)));
    final p2 = Offset(w * 0.7, h * (0.85 - (0.55 * vFactor)));
    final p3 = Offset(w, h * (0.85 - (0.80 * vFactor)).clamp(2.0, h - 2.0));

    path.moveTo(p0.dx, p0.dy);
    path.cubicTo(p1.dx, p1.dy, p2.dx, p2.dy, p3.dx, p3.dy);

    // Gradient area under curve
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.coral.withValues(alpha: isDark ? 0.25 : 0.2),
          AppTheme.coral.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppTheme.coral
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // End pulse dot
    final dotPaint = Paint()
      ..color = AppTheme.coral
      ..style = PaintingStyle.fill;
    canvas.drawCircle(p3, 3.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _VelocitySparklinePainter oldDelegate) =>
      oldDelegate.velocity != velocity || oldDelegate.isDark != isDark;
}

/// Formats a research digest as a clean, structured Markdown document for export/sharing.
String formatDigestMarkdown(UserDigest digest) {
  final buffer = StringBuffer();
  buffer.writeln('# Athena AI · Weekly Research Briefing');
  buffer.writeln('Generated: ${digest.generatedAt.toLocal().toString().split(" ")[0]}');
  buffer.writeln();

  if (digest.aiSummary.isNotEmpty) {
    buffer.writeln('## Executive AI Synthesis');
    buffer.writeln(digest.aiSummary);
    buffer.writeln();
  }

  if (digest.topTakeaways.isNotEmpty) {
    buffer.writeln('## Key Empirical Takeaways');
    for (final takeaway in digest.topTakeaways) {
      buffer.writeln('- $takeaway');
    }
    buffer.writeln();
  }

  if (digest.pulses.isNotEmpty) {
    buffer.writeln('## Topic Momentum');
    for (final p in digest.pulses) {
      final themes = p.keyThemes.isNotEmpty ? ' (${p.keyThemes.join(", ")})' : '';
      buffer.writeln('- **${p.topicName}**: ${p.paperCount} recent papers$themes');
    }
    buffer.writeln();
  }

  if (digest.sections.isNotEmpty) {
    buffer.writeln('## Featured Research');
    for (final sec in digest.sections) {
      buffer.writeln('### ${sec.title}');
      for (final paper in sec.papers) {
        final year = paper.year > 0 ? ' (${paper.year})' : '';
        final venue = paper.venueName.isNotEmpty ? ' — ${paper.venueName}' : '';
        buffer.writeln('- **${paper.title}**$year$venue');
      }
      buffer.writeln();
    }
  }

  buffer.writeln('---');
  buffer.writeln('*Curated with Athena AI · Research Intelligence Platform*');
  return buffer.toString().trim();
}
