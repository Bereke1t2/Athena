import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/citation_graph.dart';

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

class CitationGraphExplorerCard extends ConsumerStatefulWidget {
  const CitationGraphExplorerCard({super.key, required this.paperId});

  final String paperId;

  @override
  ConsumerState<CitationGraphExplorerCard> createState() => _CitationGraphExplorerCardState();
}

class _CitationGraphExplorerCardState extends ConsumerState<CitationGraphExplorerCard> {
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
                        color: AppTheme.coral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${g.totalNodes} papers · ${g.totalEdges} links',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.coral),
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
                                  ? AppTheme.coral
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
                                  ? AppTheme.coral
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
                                                    color: AppTheme.coral.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text('★ Influential', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.coral)),
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
                const _LegendDot(color: AppTheme.coral, label: 'Seed'),
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
        edgeColor = AppTheme.coral;
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
        nodeColor = AppTheme.coral;

        final glowPaint = Paint()
          ..color = AppTheme.coral.withValues(alpha: 0.25)
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
                      ? AppTheme.coral.withValues(alpha: 0.2)
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
                        ? AppTheme.coral
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
                    color: AppTheme.coral.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('★ Influential',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.coral)),
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
