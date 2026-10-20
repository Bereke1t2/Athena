import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import 'digest_notifier.dart';

class DigestScreen extends ConsumerWidget {
  const DigestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(digestNotifierProvider);
    final notifier = ref.read(digestNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Research Digest',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: state.isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'Regenerate Briefing',
            onPressed: state.isGenerating ? null : () => notifier.regenerate(),
          ),
        ],
      ),
      body: Builder(
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

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E2330), const Color(0xFF151822)]
                        : [const Color(0xFFEFF6FF), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C3345) : const Color(0xFFDBEAFE),
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
                            color: AppTheme.canaryYellow.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            digest.frequency.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.canaryYellow,
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
                      'Executive Research Briefing',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'High-velocity developments, empirical consensus, and curated breakthroughs tailored to your scientific focus.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: digest.pulses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      final pulse = digest.pulses[i];
                      return Container(
                        width: 170,
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
                                const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.canaryYellow),
                                const SizedBox(width: 4),
                                Text(
                                  '+${pulse.velocity.toStringAsFixed(1)}x velocity',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.canaryYellow,
                                  ),
                                ),
                              ],
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
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          '${paper.year} · ${paper.venueName.isNotEmpty ? paper.venueName : "Preprint"}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                          ),
                                        ),
                                        const Spacer(),
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
          );
        },
      ),
    );
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
        color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
      ),
    );
  }
}
