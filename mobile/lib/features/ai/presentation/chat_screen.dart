import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ai_formatted_text.dart';
import '../../../core/widgets/athena_branding.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../../core/widgets/suggested_prompt_card.dart';
import '../../feed/domain/feed.dart';
import '../../feed/presentation/feed_notifier.dart';
import '../domain/ai_models.dart';
import 'chat_notifier.dart';

/// Resarc Conversational Research Assistant Screen.
/// Grounded streaming AI conversation with the technical dot-grid canvas,
/// hero exploration state, and editorial citations.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    this.paperId,
    this.paperTitle,
    this.initialQuery,
  });

  final String? paperId;
  final String? paperTitle;
  final String? initialQuery;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _input.addListener(_onInputChanged);
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSend(widget.initialQuery!);
      });
    }
  }

  void _onInputChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _resolveActivePaperId() {
    if (widget.paperId != null && widget.paperId!.isNotEmpty) {
      return widget.paperId!;
    }
    final feedAsync = ref.watch(feedNotifierProvider(FeedSection.latest));
    final firstItem = feedAsync.valueOrNull?.items.firstOrNull;
    if (firstItem != null && firstItem.paper.id.isNotEmpty) {
      return firstItem.paper.id;
    }
    return '';
  }

  void _handleSend([String? explicitText]) {
    final text = (explicitText ?? _input.text).trim();
    if (text.isEmpty) return;

    final activePaperId = _resolveActivePaperId();
    if (activePaperId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting to scholarly research corpus, please try again in a moment...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _input.clear();
    ref.read(chatThreadProvider(activePaperId).notifier).send(text);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent + 280,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  String _buildGreeting() {
    final hour = DateTime.now().hour;
    final timeGreeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    return '$timeGreeting, Scholar.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activePaperId = _resolveActivePaperId();
    final state = activePaperId.isNotEmpty
        ? ref.watch(chatThreadProvider(activePaperId))
        : const ChatThreadState();

    final feedAsync = ref.watch(feedNotifierProvider(FeedSection.latest));
    final firstItem = feedAsync.valueOrNull?.items.firstOrNull;
    final targetSuggestedTitle = widget.paperTitle ??
        (firstItem != null
            ? firstItem.paper.title
            : 'Exploring the Use of Technology in Elementary School Classrooms');

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFFBFBFB),
      body: DotGridBackground(
        dotColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08),
        spacing: 18.0,
        dotRadius: 1.0,
        child: SafeArea(
          child: Column(
            children: [
              // Editorial Top Bar: Back / Menu, Athena Brand Mark, Refresh / Clear
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                          ),
                          color: isDark ? const Color(0xFF181A20) : Colors.white,
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 18),
                      ),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),

                    // Centered Brandmark with Coral Emblem and Emerald Green center dot
                    const AthenaEditorialBrandMark(
                      title: 'ATHENA',
                      emblemSize: 20,
                      fontSize: 18,
                    ),

                    IconButton(
                      tooltip: 'New Session',
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                          ),
                          color: isDark ? const Color(0xFF181A20) : Colors.white,
                        ),
                        child: const Icon(Icons.refresh_rounded, size: 18),
                      ),
                      onPressed: () {
                        if (activePaperId.isNotEmpty) {
                          ref.invalidate(chatThreadProvider(activePaperId));
                        }
                      },
                    ),
                  ],
                ),
              ),

              // RAG Grounding Context Banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161922) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF242936) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF10B981), // Emerald green verification dot
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.paperTitle != null
                            ? 'Grounding: ${widget.paperTitle}'
                            : (firstItem != null
                                ? 'Grounding: ${firstItem.paper.title}'
                                : 'RAG Grounded: Peer-Reviewed Scientific Corpus'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'VERIFIED',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Chat Thread or Empty Exploration View
              Expanded(
                child: state.messages.isEmpty && state.streaming.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Greeting Headline
                            Text(
                              _buildGreeting(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'What are we exploring today?',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: isDark ? Colors.white : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Suggested Prompt Card
                            SuggestedPromptCard(
                              actionLead: 'Summarize the methodology',
                              targetTitle: targetSuggestedTitle,
                              onTap: () {
                                _handleSend(
                                  'Summarize the methodology used in the paper "$targetSuggestedTitle"',
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Scholarly Prompts Section
                            Text(
                              'EXPLORE SCHOLARLY INQUIRIES',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: [
                                for (final q in [
                                  'What is the core breakthrough?',
                                  'Explain the methodology simply',
                                  'What are the key limitations?',
                                  'Compare findings with consensus',
                                ])
                                  ActionChip(
                                    label: Text(
                                      q,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    backgroundColor:
                                        isDark ? const Color(0xFF181A20) : Colors.white,
                                    side: BorderSide(
                                      color: isDark
                                          ? const Color(0xFF282C38)
                                          : const Color(0xFFE5E7EB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    onPressed: () => _handleSend(q),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: state.messages.length +
                            (state.streaming.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == state.messages.length) {
                            return _Bubble(
                              message: ChatMessage(
                                id: 'streaming',
                                role: 'assistant',
                                content: state.streaming,
                              ),
                              streaming: true,
                            );
                          }
                          return _Bubble(message: state.messages[i]);
                        },
                      ),
              ),

              // Docked Universal Resarc AI Research Prompt Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161922) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Full-width Input Text Field
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 5,
                          enabled: !state.sending,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSend(),
                          cursorColor: AppTheme.coral,
                          style: TextStyle(
                            fontSize: 15.0,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            height: 1.35,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Ask Athena anything about this research…',
                            hintStyle: TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: isDark ? const Color(0xFF8B92A0) : const Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          ),
                        ),
                      ),

                      // Clear button when text is entered
                      if (_input.text.isNotEmpty && !state.sending) ...[
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          onPressed: () => _input.clear(),
                          tooltip: 'Clear',
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Upward Circular Send Button
                      InkWell(
                        onTap: (state.sending || _input.text.trim().isEmpty)
                            ? null
                            : () => _handleSend(),
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _input.text.trim().isEmpty && !state.sending
                                ? (isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB))
                                : AppTheme.coral,
                          ),
                          child: Center(
                            child: state.sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    Icons.arrow_upward_rounded,
                                    color: _input.text.trim().isEmpty && !state.sending
                                        ? (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF))
                                        : Colors.white,
                                    size: 20,
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.streaming = false});

  final ChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUser = message.isUser;

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.84,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E222D) : const Color(0xFF111827),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: isDark
                  ? AppTheme.coral.withValues(alpha: 0.45)
                  : const Color(0xFF282C38),
              width: 1.2,
            ),
          ),
          child: Text(
            message.content,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF9FAFB),
              height: 1.45,
            ),
          ),
        ),
      );
    }

    // Assistant grounded card
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161922) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Assistant Brand Header
            Row(
              children: [
                const AthenaArcEmblem(size: 14),
                const SizedBox(width: 7),
                const Text(
                  'ATHENA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppTheme.coral,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'GROUNDED',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Formatted Response
            AiFormattedText(
              text: message.content,
              streaming: streaming,
              baseStyle: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
              ),
            ),

            // Citations
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < message.citations.length; i++)
                    _CitationChip(index: i + 1, citation: message.citations[i]),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.index, required this.citation});

  final int index;
  final ChatCitation citation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      avatar: CircleAvatar(
        radius: 8,
        backgroundColor: AppTheme.coral.withValues(alpha: 0.15),
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AppTheme.coral,
          ),
        ),
      ),
      label: Text(
        citation.sectionPath.isNotEmpty ? citation.sectionPath : 'source',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
        ),
      ),
      tooltip: citation.quote,
      visualDensity: VisualDensity.compact,
      backgroundColor: isDark ? const Color(0xFF1E222D) : const Color(0xFFF3F4F6),
      side: BorderSide(
        color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
      ),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          backgroundColor: isDark ? const Color(0xFF181A20) : Colors.white,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.65,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.format_quote_rounded, size: 18, color: AppTheme.coral),
                        SizedBox(width: 6),
                        Text(
                          'Source Excerpt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    if (citation.sectionPath.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        citation.sectionPath,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.coral,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          citation.quote,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
