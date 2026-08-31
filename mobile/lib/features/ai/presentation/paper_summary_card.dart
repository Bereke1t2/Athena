import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ai_formatted_text.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(summaryNotifierProvider(widget.paperId));
    final notifier = ref.read(summaryNotifierProvider(widget.paperId).notifier);
    final data = state.data;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF292E3D) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppTheme.canaryYellow.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppTheme.canaryYellow,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI RESEARCH SUMMARY',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF141416),
                    ),
                  ),
                ],
              ),
              if (data is AsyncData<PaperSummaryAI> && data.value.cacheHit)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.canaryYellow.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 13, color: AppTheme.canaryYellow),
                      SizedBox(width: 3),
                      Text(
                        'INSTANT',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.canaryYellow,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Level chips appear once summary exists or is loading
          if (data is AsyncData<PaperSummaryAI> ||
              (data is AsyncLoading<PaperSummaryAI> && data.hasValue))
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final level in ExplanationLevel.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          level.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: state.level == level ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        selected: state.level == level,
                        onSelected: (_) => notifier.load(level),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          _body(context, state, notifier, isDark),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, SummaryState state, SummaryNotifier notifier, bool isDark) {
    final data = state.data;

    // Show error state with retry.
    if (data is AsyncError<PaperSummaryAI>) {
      return ErrorView(failure: data.error, onRetry: notifier.load);
    }

    // Not generated yet (idle): explicit affordance instead of auto-fetching.
    if (data == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Generate a grounded, multi-level scientific summary with key findings, methodology, and limitations.',
            style: TextStyle(
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
              foregroundColor: isDark ? const Color(0xFF141416) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => notifier.load(),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text(
              'Generate AI Summary',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
    }

    return data.when(
      skipLoadingOnReload: true,
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(height: 10),
              Text(
                'Synthesizing paper with AI…',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => ErrorView(failure: e, onRetry: notifier.load),
      data: (summary) => _summary(context, summary, isDark),
    );
  }

  Widget _summary(BuildContext context, PaperSummaryAI s, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TLDR Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TL;DR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    'Grounded in ${s.grounding.basedOn.replaceAll('_', ' ')}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AiFormattedText(
                text: s.tldr.isNotEmpty ? s.tldr : 'No TL;DR available.',
                baseStyle: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: isDark ? Colors.white : const Color(0xFF141416),
                ),
              ),
            ],
          ),
        ),

        if (s.sections.simpleExplanation.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SummarySection(
            title: 'In Simple Terms',
            body: s.sections.simpleExplanation,
            isDark: isDark,
          ),
        ],

        if (s.sections.keyFindings.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'KEY FINDINGS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          for (final f in s.sections.keyFindings)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AiFormattedText(
                      text: f,
                      baseStyle: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        if (s.sections.methodology.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SummarySection(
            title: 'Methodology',
            body: s.sections.methodology,
            isDark: isDark,
          ),
        ],

        if (s.sections.results.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SummarySection(
            title: 'Results',
            body: s.sections.results,
            isDark: isDark,
          ),
        ],

        if (s.sections.limitations.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'LIMITATIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          for (final l in s.sections.limitations)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 6),
                    child: Text(
                      '•',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: AiFormattedText(
                      text: l,
                      baseStyle: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],

        if (s.sections.whyItMatters.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262118) : const Color(0xFFFFFDE8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.canaryYellow.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WHY IT MATTERS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: Color(0xFFEAB308),
                  ),
                ),
                const SizedBox(height: 4),
                AiFormattedText(
                  text: s.sections.whyItMatters,
                  baseStyle: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF141416),
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

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.title,
    required this.body,
    required this.isDark,
  });

  final String title;
  final String body;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        AiFormattedText(
          text: body,
          baseStyle: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}
