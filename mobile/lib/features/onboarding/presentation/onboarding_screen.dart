import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di.dart';
import '../../../core/prefs/prefs_providers.dart';
import '../../../core/prefs/user_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../topics/domain/topic.dart';

const _fallbackTopics = <Topic>[
  Topic(slug: 'design', name: 'Design', kind: 'topic', paperCountEstimate: 120),
  Topic(slug: 'ai-tech', name: 'AI & Tech', kind: 'field', paperCountEstimate: 5400),
  Topic(slug: 'product', name: 'Product', kind: 'topic', paperCountEstimate: 230),
  Topic(slug: 'psychology', name: 'Psychology', kind: 'field', paperCountEstimate: 1400),
  Topic(slug: 'business', name: 'Business', kind: 'field', paperCountEstimate: 3200),
  Topic(slug: 'history', name: 'History', kind: 'field', paperCountEstimate: 980),
  Topic(slug: 'health', name: 'Health', kind: 'field', paperCountEstimate: 4100),
  Topic(slug: 'finance', name: 'Finance', kind: 'field', paperCountEstimate: 2100),
  Topic(slug: 'culture', name: 'Culture', kind: 'topic', paperCountEstimate: 450),
  Topic(slug: 'climate', name: 'Climate', kind: 'field', paperCountEstimate: 870),
  Topic(slug: 'startups', name: 'Startups', kind: 'topic', paperCountEstimate: 620),
  Topic(slug: 'film', name: 'Film & Media', kind: 'topic', paperCountEstimate: 310),
  Topic(slug: 'machine-learning', name: 'Machine Learning', kind: 'field', paperCountEstimate: 4200),
  Topic(slug: 'neuroscience', name: 'Neuroscience', kind: 'field', paperCountEstimate: 1900),
  Topic(slug: 'physics', name: 'Physics', kind: 'field', paperCountEstimate: 2400),
  Topic(slug: 'robotics', name: 'Robotics', kind: 'topic', paperCountEstimate: 1100),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _minSelection = 3;

  List<Topic>? _topics;
  final Set<String> _selected = {'design', 'ai-tech', 'business'};

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  Future<void> _loadTopics() async {
    try {
      final page = await ref.read(topicsRepositoryProvider).list(limit: 100);
      if (!mounted) return;
      setState(() {
        final items = page.items.where((t) => t.kind == 'field' || t.paperCountEstimate >= 0).toList();
        if (items.isNotEmpty) {
          _topics = items;
        } else {
          _topics = _fallbackTopics;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _topics = _fallbackTopics;
      });
    }
  }

  void _toggle(String slug) {
    setState(() {
      if (_selected.contains(slug)) {
        _selected.remove(slug);
      } else if (_selected.length < UserPreferences.maxTopics) {
        _selected.add(slug);
      }
    });
  }

  Future<void> _finish() async {
    if (_selected.isEmpty) {
      _selected.addAll(['ai-tech', 'machine-learning', 'neuroscience']);
    }
    ref.read(selectedTopicsProvider.notifier).replace(_selected.toList());
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topics = _topics ?? _fallbackTopics;
    final canContinue = _selected.length >= _minSelection;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Step Indicator & Skip Action
            AnimatedEntrance(
              delay: const Duration(milliseconds: 50),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222630) : const Color(0xFFEDEFE3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP 01 — PERSONALIZE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Main Bold Headline
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        'Turn anything you\nread into audio you\nfinish.',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 32,
                          height: 1.15,
                          letterSpacing: -0.8,
                          color: isDark ? Colors.white : const Color(0xFF141416),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        'Choose at least 3 topics. Athena shapes a daily listening brief around them.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Topic Chips Wrap (Listenly pill chips)
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 200),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: [
                          for (final t in topics)
                            _TopicPill(
                              topic: t,
                              isSelected: _selected.contains(t.slug),
                              onTap: () => _toggle(t.slug),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Selected Topics Counter Badge
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 250),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222B) : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF333846) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.canaryYellow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_selected.length} selected',
                                style: const TextStyle(
                                  color: Color(0xFF141416),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              canContinue ? 'Ready to continue' : 'min 3 to continue',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // 3-Column Metrics / Trust Stats
                    AnimatedEntrance(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1D24) : const Color(0xFFFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E3340) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _MetricColumn(
                              value: '40k',
                              label: 'daily listeners',
                              isDark: isDark,
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                            ),
                            _MetricColumn(
                              value: '4.9',
                              label: 'avg listener rating',
                              isDark: isDark,
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                            ),
                            _MetricColumn(
                              value: '12',
                              label: 'languages',
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom CTA Section
            AnimatedEntrance(
              delay: const Duration(milliseconds: 350),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canContinue
                              ? (isDark ? const Color(0xFFFEEA66) : const Color(0xFF141416))
                              : (isDark ? const Color(0xFF2A2E3A) : const Color(0xFFD1D5DB)),
                          foregroundColor: canContinue
                              ? (isDark ? const Color(0xFF141416) : Colors.white)
                              : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                        onPressed: canContinue ? _finish : null,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '►',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Takes about 30 seconds · you can re-tune later',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({
    required this.topic,
    required this.isSelected,
    required this.onTap,
  });

  final Topic topic;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFFFEEA66) : const Color(0xFF141416))
                : (isDark ? const Color(0xFF1C2028) : const Color(0xFFFFFFFF)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFFFEEA66) : const Color(0xFF141416))
                  : (isDark ? const Color(0xFF2F3544) : const Color(0xFFE5E7EB)),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: (isDark ? const Color(0xFFFEEA66) : Colors.black).withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFF141416) : Colors.white,
                  ),
                ),
              ],
              Text(
                topic.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? (isDark ? const Color(0xFF141416) : Colors.white)
                      : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111827),
            letterSpacing: -0.3,
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
