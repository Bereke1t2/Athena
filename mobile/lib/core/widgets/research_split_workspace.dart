import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/annotations/domain/annotation.dart';
import '../../features/annotations/presentation/annotations_notifier.dart';
import '../theme/app_theme.dart';

/// Screen width breakpoint for switching to the productivity two-pane split workspace.
const double kDesktopSplitBreakpoint = 1024.0;

enum ResearchSidebarTab {
  chat,
  annotations,
}

/// Adaptive split-screen workspace for Desktop, Tablet, and Web viewports (>= 1024px).
/// - Left pane (60% width): Reader or Paper Detail document viewer.
/// - Right pane (40% width): Grounded AI conversational assistant & annotations inspector.
/// Automatically degrades to standard single-pane layout on screens below 1024px.
class ResearchSplitWorkspace extends ConsumerStatefulWidget {
  const ResearchSplitWorkspace({
    super.key,
    required this.paperId,
    required this.paperTitle,
    required this.mainPane,
    this.initialTab = ResearchSidebarTab.chat,
    this.canCollapse = true,
  });

  final String paperId;
  final String paperTitle;
  final Widget mainPane;
  final ResearchSidebarTab initialTab;
  final bool canCollapse;

  @override
  ConsumerState<ResearchSplitWorkspace> createState() =>
      _ResearchSplitWorkspaceState();
}

class _ResearchSplitWorkspaceState
    extends ConsumerState<ResearchSplitWorkspace> {
  late ResearchSidebarTab _activeTab;
  bool _isSidebarVisible = true;
  AnnotationColor? _selectedColorFilter;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final isDesktopWorkspace = screenWidth >= kDesktopSplitBreakpoint;

        // Narrow / mobile viewport: direct single-pane document
        if (!isDesktopWorkspace) {
          return widget.mainPane;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Row(
          children: [
            // Left Pane (60% reading / main document content)
            Expanded(
              flex: 6,
              child: widget.mainPane,
            ),

            // Vertical Border Divider
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
            ),

            // Right Pane (40% productivity workbench)
            if (_isSidebarVisible)
              Expanded(
                flex: 4,
                child: _buildProductivitySidebar(context, isDark),
              )
            else if (widget.canCollapse)
              _buildCollapsedRail(context, isDark),
          ],
        );
      },
    );
  }

  Widget _buildCollapsedRail(BuildContext context, bool isDark) {
    final annotationsAsync = ref.watch(paperAnnotationsProvider(widget.paperId));
    final count = annotationsAsync.valueOrNull?.length ?? 0;

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : const Color(0xFFF9FAFB),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Expand Productivity Sidebar',
            onPressed: () {
              setState(() {
                _isSidebarVisible = true;
              });
            },
          ),
          const Divider(height: 20),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppTheme.coral, size: 20),
            tooltip: 'Open AI Assistant',
            onPressed: () {
              setState(() {
                _isSidebarVisible = true;
                _activeTab = ResearchSidebarTab.chat;
              });
            },
          ),
          const SizedBox(height: 8),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 22),
                tooltip: 'Open Annotations',
                onPressed: () {
                  setState(() {
                    _isSidebarVisible = true;
                    _activeTab = ResearchSidebarTab.annotations;
                  });
                },
              ),
              if (count > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.coral,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader(BuildContext context, bool isDark) {
    final annotationsAsync = ref.watch(paperAnnotationsProvider(widget.paperId));
    final count = annotationsAsync.valueOrNull?.length ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : const Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Tab 1: AI Chat Chip
                  InkWell(
                    onTap: () {
                      setState(() {
                        _activeTab = ResearchSidebarTab.chat;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeTab == ResearchSidebarTab.chat
                            ? AppTheme.coral.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome,
                            size: 15,
                            color: _activeTab == ResearchSidebarTab.chat
                                ? AppTheme.coral
                                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'AI Assistant',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _activeTab == ResearchSidebarTab.chat
                                  ? AppTheme.coral
                                  : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Tab 2: Annotations Chip
                  InkWell(
                    onTap: () {
                      setState(() {
                        _activeTab = ResearchSidebarTab.annotations;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _activeTab == ResearchSidebarTab.annotations
                            ? AppTheme.coral.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            size: 16,
                            color: _activeTab == ResearchSidebarTab.annotations
                                ? AppTheme.coral
                                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Notes & Highlights ($count)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _activeTab == ResearchSidebarTab.annotations
                                  ? AppTheme.coral
                                  : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
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
          if (widget.canCollapse) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              tooltip: 'Collapse sidebar',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _isSidebarVisible = false;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductivitySidebar(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0F1117) : Colors.white,
      child: Column(
        children: [
          _buildSidebarHeader(context, isDark),
          Expanded(
            child: _activeTab == ResearchSidebarTab.chat
                ? _buildChatPane(context, isDark)
                : _buildAnnotationsPane(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPane(BuildContext context, bool isDark) {
    return const SizedBox.shrink();
  }

  Widget _buildAnnotationsPane(BuildContext context, bool isDark) {
    return const SizedBox.shrink();
  }
}
