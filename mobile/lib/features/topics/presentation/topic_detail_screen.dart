import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/paper_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../follows/presentation/follows_notifier.dart';
import '../domain/topic.dart';
import 'topics_notifier.dart';

class TopicDetailScreen extends ConsumerStatefulWidget {
  const TopicDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen> {
  String _sort = 'newest';

  @override
  Widget build(BuildContext context) {
    final topicAsync = ref.watch(topicDetailControllerProvider(widget.slug));
    final papersAsync = ref.watch(topicPapersNotifierProvider(widget.slug, sort: _sort));

    return Scaffold(
      appBar: AppBar(title: Text(topicAsync.valueOrNull?.name ?? 'Topic')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topicDetailControllerProvider(widget.slug));
          ref.invalidate(topicPapersNotifierProvider(widget.slug, sort: _sort));
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 350) {
              final page = papersAsync.valueOrNull;
              if (page?.nextCursor != null) {
                ref.read(topicPapersNotifierProvider(widget.slug, sort: _sort).notifier).loadMore();
              }
            }
            return false;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              topicAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  failure: e,
                  onRetry: () => ref.invalidate(topicDetailControllerProvider(widget.slug)),
                ),
                data: (topic) => _header(context, ref, topic),
              ),
              const Divider(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      'PAPERS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Newest'),
                      selected: _sort == 'newest',
                      onSelected: (val) {
                        if (val && _sort != 'newest') {
                          setState(() => _sort = 'newest');
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Most Cited'),
                      selected: _sort == 'citations',
                      onSelected: (val) {
                        if (val && _sort != 'citations') {
                          setState(() => _sort = 'citations');
                        }
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              papersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  failure: e,
                  onRetry: () => ref.invalidate(topicPapersNotifierProvider(widget.slug, sort: _sort)),
                ),
                data: (page) {
                  final theme = Theme.of(context);
                  if (page.items.isEmpty) {
                    return const EmptyView(
                      icon: Icons.article_outlined,
                      title: 'No papers under this topic yet',
                    );
                  }
                  return Column(
                    children: [
                      for (final p in page.items)
                        PaperCard(paper: p, onTap: () => context.push('/papers/${p.id}')),
                      if (page.nextCursor != null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              "End of papers for this topic",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, Topic topic) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final followsState = ref.watch(followsNotifierProvider);
    final isFollowed = followsState.isTopicFollowed(topic.slug);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(label: Text(topic.isField ? 'Field' : 'Topic')),
                    Chip(label: Text('${topic.paperCountEstimate} papers')),
                    if (topic.parentName != null)
                      Chip(label: Text('in ${topic.parentName!}')),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowed
                      ? (isDark ? const Color(0xFF232836) : const Color(0xFFE5E7EB))
                      : AppTheme.canaryYellow,
                  foregroundColor: isFollowed
                      ? (isDark ? Colors.white : const Color(0xFF141416))
                      : const Color(0xFF141416),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final isAuthenticated = ref.read(authNotifierProvider).isAuthenticated;
                  if (!isAuthenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please sign in to follow topics'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    context.push('/login');
                    return;
                  }
                  ref.read(followsNotifierProvider.notifier).toggleTopicFollow(topic.slug, topic.name);
                },
                icon: Icon(isFollowed ? Icons.check_rounded : Icons.add_rounded, size: 16),
                label: Text(
                  isFollowed ? 'Following' : 'Follow Topic',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ],
          ),
          if (topic.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(topic.description, style: theme.textTheme.bodyMedium),
          ],
          _TopicTaxonomyGraphCard(topic: topic),
          if (topic.children.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Subtopics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in topic.children)
                  ActionChip(
                    label: Text(Topic.displayNameForSlug(c)),
                    onPressed: () => context.push('/topics/$c'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TopicTaxonomyGraphCard extends StatelessWidget {
  const _TopicTaxonomyGraphCard({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF232734) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(Icons.account_tree_rounded, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Taxonomy Knowledge Graph',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${(topic.children.length) + (topic.parentSlug != null ? 2 : 1)} nodes',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF1E2330) : const Color(0xFFE2E8F0)),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 180),
                    painter: _TopicTaxonomyPainter(
                      topic: topic,
                      isDark: isDark,
                    ),
                  ),
                  _TopicTaxonomyOverlay(topic: topic),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicNodeLayout {
  _TopicNodeLayout({
    required this.slug,
    required this.name,
    required this.position,
    required this.radius,
    required this.isCenter,
    required this.isParent,
  });

  final String slug;
  final String name;
  final Offset position;
  final double radius;
  final bool isCenter;
  final bool isParent;
}

List<_TopicNodeLayout> _layoutTopicNodes(Topic topic, Size size) {
  final center = Offset(size.width / 2, topic.parentSlug != null ? size.height * 0.52 : size.height * 0.42);
  final nodes = <_TopicNodeLayout>[];

  // Center node
  nodes.add(_TopicNodeLayout(
    slug: topic.slug,
    name: topic.name,
    position: center,
    radius: 17.0,
    isCenter: true,
    isParent: false,
  ));

  // Parent node (with fallback if topic is being retrofitted)
  final parentSlug = topic.parentSlug ?? (topic.isField ? null : 'computer-science');
  final parentName = topic.parentName ?? (topic.isField ? null : 'Computer Science');
  if (parentSlug != null) {
    nodes.add(_TopicNodeLayout(
      slug: parentSlug,
      name: parentName ?? Topic.displayNameForSlug(parentSlug),
      position: Offset(size.width / 2, 28),
      radius: 14.0,
      isCenter: false,
      isParent: true,
    ));
  }

  // Children nodes
  final children = topic.children.take(5).toList();
  if (children.isNotEmpty) {
    final yTarget = topic.parentSlug != null ? size.height * 0.82 : size.height * 0.78;
    final spacing = math.min(68.0, (size.width - 40) / math.max(children.length, 1));
    final startX = (size.width / 2) - ((children.length - 1) * spacing / 2);

    for (int i = 0; i < children.length; i++) {
      final childSlug = children[i];
      nodes.add(_TopicNodeLayout(
        slug: childSlug,
        name: Topic.displayNameForSlug(childSlug),
        position: Offset(startX + (i * spacing), yTarget),
        radius: 12.0,
        isCenter: false,
        isParent: false,
      ));
    }
  }

  return nodes;
}

class _TopicTaxonomyPainter extends CustomPainter {
  _TopicTaxonomyPainter({required this.topic, required this.isDark});

  final Topic topic;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = _layoutTopicNodes(topic, size);
    final centerNode = nodes.firstWhere((n) => n.isCenter);

    // 1. Draw connecting edges
    final edgePaint = Paint()
      ..color = isDark
          ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
          : const Color(0xFF60A5FA).withValues(alpha: 0.5)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    for (final node in nodes) {
      if (node.isCenter) continue;
      canvas.drawLine(centerNode.position, node.position, edgePaint);

      // Edge midpoint dot
      final mid = Offset((centerNode.position.dx + node.position.dx) / 2,
          (centerNode.position.dy + node.position.dy) / 2);
      final dotPaint = Paint()
        ..color = isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(mid, 2.0, dotPaint);
    }

    // 2. Draw nodes
    for (final node in nodes) {
      Color nodeColor;
      if (node.isCenter) {
        nodeColor = AppTheme.canaryYellow;
        final glowPaint = Paint()
          ..color = AppTheme.canaryYellow.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5;
        canvas.drawCircle(node.position, node.radius + 3.0, glowPaint);
      } else if (node.isParent) {
        nodeColor = const Color(0xFF10B981);
      } else {
        nodeColor = const Color(0xFF3B82F6);
      }

      final fillPaint = Paint()
        ..color = nodeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(node.position, node.radius, fillPaint);

      final borderPaint = Paint()
        ..color = isDark ? const Color(0xFF0F1117) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(node.position, node.radius, borderPaint);

      // Node label
      final text = node.name.length > 10 ? '${node.name.substring(0, 9)}…' : node.name;
      final textSpan = TextSpan(
        text: text,
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

      final labelY = node.isParent
          ? node.position.dy - node.radius - textPainter.height - 1.5
          : node.position.dy + node.radius + 2.0;

      textPainter.paint(
        canvas,
        Offset(node.position.dx - (textPainter.width / 2), labelY),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TopicTaxonomyPainter oldDelegate) {
    return oldDelegate.topic != topic || oldDelegate.isDark != isDark;
  }
}

class _TopicTaxonomyOverlay extends StatelessWidget {
  const _TopicTaxonomyOverlay({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final nodes = _layoutTopicNodes(topic, size);

        return Stack(
          children: [
            for (final node in nodes)
              if (!node.isCenter)
                Positioned(
                  left: node.position.dx - 24,
                  top: node.position.dy - 24,
                  width: 48,
                  height: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => context.push('/topics/${node.slug}'),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}
