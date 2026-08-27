import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di.dart';
import '../../../core/prefs/prefs_providers.dart';
import '../../../core/prefs/user_preferences.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../../core/widgets/state_views.dart';
import '../../topics/domain/topic.dart';

const _fallbackTopics = <Topic>[
  Topic(slug: 'machine-learning', name: 'Machine Learning', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'artificial-intelligence', name: 'Artificial Intelligence', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'natural-language-processing', name: 'Natural Language Processing', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'computer-vision', name: 'Computer Vision', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'reinforcement-learning', name: 'Reinforcement Learning', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'neuroscience', name: 'Neuroscience', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'biology', name: 'Biology', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'genomics', name: 'Genomics', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'physics', name: 'Physics', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'quantum-computing', name: 'Quantum Computing', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'climate-science', name: 'Climate Science', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'medicine', name: 'Medicine', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'epidemiology', name: 'Epidemiology', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'economics', name: 'Economics', kind: 'field', paperCountEstimate: 0),
  Topic(slug: 'robotics', name: 'Robotics', kind: 'topic', paperCountEstimate: 0),
  Topic(slug: 'cryptography', name: 'Cryptography', kind: 'topic', paperCountEstimate: 0),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _minSelection = 3;

  final _filterController = TextEditingController();
  List<Topic>? _topics;
  Object? _error;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final page = await ref.read(topicsRepositoryProvider).list(limit: 100);
      if (!mounted) return;
      setState(() {
        _topics = page.items.where((t) => t.kind == 'field' || t.paperCountEstimate >= 0).toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
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
      _selected.addAll(['machine-learning', 'artificial-intelligence', 'neuroscience']);
    }
    ref.read(selectedTopicsProvider.notifier).replace(_selected.toList());
    if (context.mounted) context.go('/');
  }

  void _showTopicPickerSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final topics = _topics ?? (_error != null ? _fallbackTopics : null);
            final query = _filterController.text.trim().toLowerCase();
            final visible = topics
                    ?.where((t) => query.isEmpty || t.name.toLowerCase().contains(query))
                    .toList() ??
                const <Topic>[];

            final canFinish = _selected.length >= _minSelection;

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Select Topics of Interest',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Pick at least $_minSelection topics to curate your research feed',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SearchBar(
                      controller: _filterController,
                      hintText: 'Filter research fields…',
                      leading: const Icon(Icons.search),
                      onChanged: (_) => setSheetState(() {}),
                    ),
                  ),
                  Expanded(
                    child: topics == null && _error == null
                        ? const Center(child: CircularProgressIndicator())
                        : visible.isEmpty
                            ? const EmptyView(
                                icon: Icons.category_outlined,
                                title: 'No matching topics',
                                subtitle: 'Try a different keyword.',
                              )
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final t in visible)
                                      FilterChip(
                                        label: Text(t.name),
                                        selected: _selected.contains(t.slug),
                                        onSelected: (_) {
                                          _toggle(t.slug);
                                          setSheetState(() {});
                                        },
                                        showCheckmark: true,
                                      ),
                                  ],
                                ),
                              ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: canFinish
                            ? () {
                                Navigator.pop(context);
                                _finish();
                              }
                            : null,
                        child: Text(
                          _selected.isEmpty
                              ? 'Pick at least 3 topics'
                              : 'Done (${_selected.length} selected)',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF1B2256), Color(0xFF0F1332)]
                : [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.88),
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Athena Goddess Crest Logo & Theme Toggle
              AnimatedEntrance(
                delay: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'ATHENA',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          ref.read(appThemeModeProvider.notifier).toggle();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Animated Hero Illustration with Goddess of Wisdom Crest
              Expanded(
                child: AnimatedEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Aura Spheres
                      Positioned(
                        right: 40,
                        top: 30,
                        child: Container(
                          width: 85,
                          height: 85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 24,
                        bottom: 40,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),

                      // Animated Athena Owl Hero Graphic Container
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AthenaOwlCrest(size: 76),
                              const SizedBox(height: 18),
                              Text(
                                'GODDESS OF WISDOM & RESEARCH',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Title & Mythology Subtitle Section
              AnimatedEntrance(
                delay: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const Text(
                        'Read Research\nExpand Your Mind',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Grounded in academic truth & wisdom. Explore 5M+ papers across artificial intelligence, neuroscience, physics & philosophy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Bottom Action Pill Buttons
              AnimatedEntrance(
                delay: const Duration(milliseconds: 400),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                  child: Column(
                    children: [
                      // Primary Pill Button ("Get Started")
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9800),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                          ),
                          onPressed: _finish,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Secondary Pill Button ("Choose Topics")
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.12),
                          ),
                          onPressed: () => _showTopicPickerSheet(context),
                          child: Text(
                            _selected.isEmpty
                                ? 'Choose Research Topics'
                                : '${_selected.length} Topics Picked',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
