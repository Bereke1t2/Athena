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
  String _selectedModel = 'arc-1a';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
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
      // Global exploration: navigate to search or chat
      context.push('/search?q=${Uri.encodeComponent(query)}');
    }
    _controller.clear();
  }

  void _showModelPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF181A20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final models = [
          ('arc-1a', 'Gemini 3.5 Flash — Ultra-fast synthesis & deep citations'),
          ('arc-1b', 'Reasoning Pro — High-depth cross-paper comparison'),
          ('arc-mini', 'On-device summary & fast offline retrieval'),
        ];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AthenaArcEmblem(size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'AI RESEARCH ENGINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...models.map((m) {
                  final isSelected = m.$1 == _selectedModel;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.coral.withValues(alpha: 0.15)
                            : (isDark ? const Color(0xFF222630) : const Color(0xFFF3F4F6)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: isSelected ? AppTheme.coral : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                      ),
                    ),
                    title: Text(
                      m.$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isSelected ? AppTheme.coral : null,
                      ),
                    ),
                    subtitle: Text(
                      m.$2,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppTheme.coral, size: 20)
                        : null,
                    onTap: () {
                      setState(() => _selectedModel = m.$1);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB);
    final buttonBorderColor = isDark ? const Color(0xFF323746) : const Color(0xFFE5E7EB);
    final iconColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

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

          // Bottom Action Row
          Row(
            children: [
              // Attachment Button
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Attach paper or dataset to prompt context'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: buttonBorderColor),
                  ),
                  child: Icon(
                    Icons.attach_file_rounded,
                    size: 18,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Voice Dictation Button
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Voice prompt listening activated...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: buttonBorderColor),
                  ),
                  child: Icon(
                    Icons.mic_none_rounded,
                    size: 18,
                    color: iconColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Model Selector Capsule Pill
              InkWell(
                onTap: () => _showModelPicker(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: buttonBorderColor),
                    color: isDark ? const Color(0xFF1F232D) : const Color(0xFFFAFAFA),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AthenaArcEmblem(size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _selectedModel,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Black Circular Send Button
              InkWell(
                onTap: _handleSubmit,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppTheme.coral : const Color(0xFF111827),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
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
