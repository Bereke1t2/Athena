import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Helper to sanitize and normalize raw AI text output, removing raw markdown
/// artefacts (hashes, unrendered asterisk markers) for plain-text presentation.
String normalizeAiText(String text) {
  var s = text;
  s = s.replaceAllMapped(RegExp(r'(^|\n)#{1,6}\s*'), (m) => m[1] ?? '');
  s = s.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1] ?? '');
  s = s.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1] ?? '');
  s = s.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m[1] ?? '');
  s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');
  s = s.replaceAllMapped(RegExp(r'(^|\n)\s*[-*•]\s+'), (m) => '${m[1] ?? ''}• ');
  return s.trim();
}

/// Rich Markdown & AI Text renderer that transforms raw LLM responses
/// (headers, bullet lists, bold, italics, code spans, chunk citations)
/// into beautiful, clean typography with no raw '#', '*', '**', or stray symbols.
class AiFormattedText extends StatelessWidget {
  const AiFormattedText({
    super.key,
    required this.text,
    this.baseStyle,
    this.streaming = false,
    this.isSelectable = true,
  });

  final String text;
  final TextStyle? baseStyle;
  final bool streaming;
  final bool isSelectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final defaultStyle = baseStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
          color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF1F2937),
        ) ??
        const TextStyle(fontSize: 14, height: 1.5);

    if (text.trim().isEmpty) {
      return streaming
          ? Text('▍', style: defaultStyle.copyWith(color: AppTheme.canaryYellow))
          : const SizedBox.shrink();
    }

    final blocks = _parseBlocks(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _buildBlock(context, blocks[i], defaultStyle, isDark, i == blocks.length - 1 && streaming),
          if (i < blocks.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    _AiBlock block,
    TextStyle baseStyle,
    bool isDark,
    bool isLastStreaming,
  ) {
    switch (block.type) {
      case _BlockType.header1:
        return _renderText(
          block.text,
          baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) + 4,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF111827),
            height: 1.3,
          ),
          isDark,
          isLastStreaming,
        );

      case _BlockType.header2:
        return _renderText(
          block.text,
          baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) + 2.5,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
            height: 1.35,
          ),
          isDark,
          isLastStreaming,
        );

      case _BlockType.header3:
        return _renderText(
          block.text,
          baseStyle.copyWith(
            fontSize: (baseStyle.fontSize ?? 14) + 1.2,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF3F4F6) : const Color(0xFF1F2937),
            height: 1.4,
          ),
          isDark,
          isLastStreaming,
        );

      case _BlockType.bullet:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7, right: 10),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Expanded(
                child: _renderText(block.text, baseStyle, isDark, isLastStreaming),
              ),
            ],
          ),
        );

      case _BlockType.numbered:
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${block.number}.',
                  style: baseStyle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                  ),
                ),
              ),
              Expanded(
                child: _renderText(block.text, baseStyle, isDark, isLastStreaming),
              ),
            ],
          ),
        );

      case _BlockType.quote:
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D26) : const Color(0xFFF3F4F6),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            border: Border(
              left: BorderSide(
                color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                width: 3,
              ),
            ),
          ),
          child: _renderText(
            block.text,
            baseStyle.copyWith(fontStyle: FontStyle.italic, height: 1.45),
            isDark,
            isLastStreaming,
          ),
        );

      case _BlockType.paragraph:
        return _renderText(block.text, baseStyle, isDark, isLastStreaming);
    }
  }

  Widget _renderText(String rawText, TextStyle baseStyle, bool isDark, bool isLastStreaming) {
    final spans = _parseInlineSpans(rawText, baseStyle, isDark);
    if (isLastStreaming) {
      spans.add(
        TextSpan(
          text: '▍',
          style: baseStyle.copyWith(
            color: AppTheme.canaryYellow,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    final textSpan = TextSpan(children: spans);

    if (isSelectable) {
      return SelectableText.rich(
        textSpan,
        style: baseStyle,
      );
    }
    return Text.rich(
      textSpan,
      style: baseStyle,
    );
  }

  List<_AiBlock> _parseBlocks(String input) {
    final lines = input.split('\n');
    final blocks = <_AiBlock>[];
    final buffer = StringBuffer();

    void flushBuffer() {
      final t = buffer.toString().trim();
      if (t.isNotEmpty) {
        blocks.add(_AiBlock(_BlockType.paragraph, t));
        buffer.clear();
      }
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushBuffer();
        continue;
      }

      if (trimmed.startsWith('# ')) {
        flushBuffer();
        blocks.add(_AiBlock(_BlockType.header1, trimmed.substring(2).trim()));
      } else if (trimmed.startsWith('## ')) {
        flushBuffer();
        blocks.add(_AiBlock(_BlockType.header2, trimmed.substring(3).trim()));
      } else if (trimmed.startsWith('### ')) {
        flushBuffer();
        blocks.add(_AiBlock(_BlockType.header3, trimmed.substring(4).trim()));
      } else if (RegExp(r'^[-*•]\s+').hasMatch(trimmed)) {
        flushBuffer();
        blocks.add(_AiBlock(_BlockType.bullet, trimmed.replaceFirst(RegExp(r'^[-*•]\s+'), '')));
      } else if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
        flushBuffer();
        final match = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 1;
          blocks.add(_AiBlock(_BlockType.numbered, match.group(2)!, number: num));
        } else {
          blocks.add(_AiBlock(_BlockType.paragraph, trimmed));
        }
      } else if (trimmed.startsWith('> ')) {
        flushBuffer();
        blocks.add(_AiBlock(_BlockType.quote, trimmed.substring(2).trim()));
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(trimmed);
      }
    }

    flushBuffer();
    return blocks;
  }

  List<InlineSpan> _parseInlineSpans(String text, TextStyle baseStyle, bool isDark) {
    final spans = <InlineSpan>[];
    // Regex pattern for bold, italics, inline code, and chunk citations [chunk N]
    final regex = RegExp(r'(\*\*\*([^*]+)\*\*\*|\*\*([^*]+)\*\*|\*([^*]+)\*|`([^`]+)`|\[chunk\s+(\d+)\]|\[(\d+)\])');
    var lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: baseStyle,
        ));
      }

      final full = match.group(0)!;
      if (full.startsWith('***') && full.endsWith('***')) {
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (full.startsWith('**') && full.endsWith('**')) {
        spans.add(TextSpan(
          text: match.group(3),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ));
      } else if (full.startsWith('*') && full.endsWith('*')) {
        spans.add(TextSpan(
          text: match.group(4),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (full.startsWith('`') && full.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              match.group(5)!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: (baseStyle.fontSize ?? 14) * 0.88,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
              ),
            ),
          ),
        ));
      } else if (full.startsWith('[chunk') || RegExp(r'^\[\d+\]$').hasMatch(full)) {
        final chunkNum = match.group(6) ?? match.group(7) ?? '1';
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppTheme.canaryYellow.withValues(alpha: isDark ? 0.22 : 0.35),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppTheme.canaryYellow.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Text(
              '[$chunkNum]',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.canaryYellow,
              ),
            ),
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return spans;
  }
}

enum _BlockType { paragraph, header1, header2, header3, bullet, numbered, quote }

class _AiBlock {
  const _AiBlock(this.type, this.text, {this.number});

  final _BlockType type;
  final String text;
  final int? number;
}
