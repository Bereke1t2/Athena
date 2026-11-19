import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ai/domain/ai_models.dart';
import '../../features/ai/presentation/chat_notifier.dart';
import '../../features/annotations/domain/annotation.dart';
import '../../features/annotations/presentation/annotations_notifier.dart';
import '../theme/app_theme.dart';
import 'ai_formatted_text.dart';

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
  final _chatInputController = TextEditingController();
  final _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _sendChatPrompt(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    _chatInputController.clear();
    ref.read(chatThreadProvider(widget.paperId).notifier).send(text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _askAiAboutAnnotation(Annotation annotation) {
    setState(() {
      _activeTab = ResearchSidebarTab.chat;
      _isSidebarVisible = true;
    });
    final prompt =
        'Explain this highlighted passage in detail: "${annotation.selectedText}". '
        '${annotation.note.isNotEmpty ? "Context note: ${annotation.note}" : ""}';
    _sendChatPrompt(prompt);
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
    final chatState = ref.watch(chatThreadProvider(widget.paperId));

    return Column(
      children: [
        // Messages list
        Expanded(
          child: chatState.messages.isEmpty && chatState.streaming.isEmpty
              ? _buildChatEmptyState(isDark)
              : ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(14),
                  itemCount: chatState.messages.length + (chatState.streaming.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < chatState.messages.length) {
                      final msg = chatState.messages[index];
                      return _buildMessageBubble(msg, isDark);
                    } else {
                      return _buildStreamingBubble(chatState.streaming, isDark);
                    }
                  },
                ),
        ),

        // Quick suggested prompt chips
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildPromptChip('Synthesize breakthrough', isDark),
              _buildPromptChip('Key methodology', isDark),
              _buildPromptChip('Limitations & caveats', isDark),
            ],
          ),
        ),

        // Chat Input Bar
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161922) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF262C3A) : const Color(0xFFE5E7EB),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatInputController,
                  onSubmitted: _sendChatPrompt,
                  decoration: InputDecoration(
                    hintText: 'Ask AI grounded on this paper...',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF373D4E) : const Color(0xFFD1D5DB),
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: chatState.sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 18),
                onPressed: chatState.sending
                    ? null
                    : () => _sendChatPrompt(_chatInputController.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.coral.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 28, color: AppTheme.coral),
            ),
            const SizedBox(height: 12),
            Text(
              'Grounded Research Assistant',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF141416),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ask deep questions grounded strictly in the full text and methodology of "${widget.paperTitle}".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String prompt, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(prompt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        backgroundColor: isDark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
        ),
        onPressed: () => _sendChatPrompt(prompt),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: isUser
              ? AppTheme.coral
              : (isDark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isUser
            ? Text(
                message.content,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              )
            : AiFormattedText(
                text: message.content,
                baseStyle: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
                ),
              ),
      ),
    );
  }

  Widget _buildStreamingBubble(String text, bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiFormattedText(
              text: text,
              baseStyle: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.coral),
                ),
                const SizedBox(width: 6),
                Text(
                  'Synthesizing...',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnotationsPane(BuildContext context, bool isDark) {
    return const SizedBox.shrink();
  }
}
