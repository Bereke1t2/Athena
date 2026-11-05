import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'athena_branding.dart';

/// Floating universal AI research prompt bar matching the Resarc editorial interface.
/// Features the text placeholder, attachment button, voice mic, arc-1a model capsule,
/// and black circular send button.
class FloatingResearchPromptBar extends StatefulWidget {
  const FloatingResearchPromptBar({
    super.key,
    this.paperId,
    this.paperTitle,
    this.initialQuery,
    this.onSubmitted,
    this.hintText = 'Curious? Ask and dive into scholarly insights',
  });

  final String? paperId;
  final String? paperTitle;
  final String? initialQuery;
  final ValueChanged<String>? onSubmitted;
  final String hintText;

  @override
  State<FloatingResearchPromptBar> createState() =>
      _FloatingResearchPromptBarState();
}

class _FloatingResearchPromptBarState extends State<FloatingResearchPromptBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (widget.onSubmitted != null && text.isNotEmpty) {
      widget.onSubmitted!(text);
      _controller.clear();
      return;
    }

    final query = text.isNotEmpty ? text : 'Summarize the core breakthrough';
    if (widget.paperId != null && widget.paperId!.isNotEmpty) {
      final titleParam = Uri.encodeComponent(widget.paperTitle ?? 'Paper');
      final queryParam = Uri.encodeComponent(query);
      context.push(
        '/papers/${widget.paperId}/chat?title=$titleParam&q=$queryParam',
      );
    } else {
      // Global exploration: navigate to chat with query
      context.push('/chat?q=${Uri.encodeComponent(query)}');
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181A20) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text Input Field
          TextField(
            controller: _controller,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _handleSubmit(),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: 10),

          // Action Row with clear and send buttons
          Row(
            children: [
              const AthenaArcEmblem(size: 16),
              const SizedBox(width: 8),
              Text(
                'ATHENA RESEARCH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _controller.clear()),
                  tooltip: 'Clear',
                ),
              const SizedBox(width: 6),
              // Circular Send Button
              InkWell(
                onTap: _handleSubmit,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.coral,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.coral.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      size: 20,
                      color: Colors.white,
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
}
