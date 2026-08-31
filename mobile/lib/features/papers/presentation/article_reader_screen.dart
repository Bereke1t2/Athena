import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ai_formatted_text.dart';
import '../domain/article_content.dart';

final articleContentProvider =
    FutureProvider.family<ArticleContent, String>((ref, id) async {
  final repo = ref.watch(paperRepositoryProvider);
  return repo.getArticleContent(id);
});

class ArticleReaderScreen extends ConsumerStatefulWidget {
  const ArticleReaderScreen({
    super.key,
    required this.paperId,
    this.title,
  });

  final String paperId;
  final String? title;

  @override
  ConsumerState<ArticleReaderScreen> createState() =>
      _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends ConsumerState<ArticleReaderScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sectionKeys = {};
  double _fontScale = 1.0; // 0.85 (Small), 1.0 (Normal), 1.15 (Large), 1.3 (XL)

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(int index) {
    final key = _sectionKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showTableOfContents(BuildContext context, ArticleContent article) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TABLE OF CONTENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: isDark
                            ? AppTheme.canaryYellow
                            : const Color(0xFF141416),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: article.sections.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
                  itemBuilder: (context, i) {
                    final section = article.sections[i];
                    return ListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                      title: Text(
                        section.displayTitle,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _scrollToSection(i);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showFontSizeSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEXT SIZE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color:
                        isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _fontOption(context, 'Small', 0.85, isDark),
                    _fontOption(context, 'Normal', 1.0, isDark),
                    _fontOption(context, 'Large', 1.15, isDark),
                    _fontOption(context, 'Extra', 1.3, isDark),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fontOption(
      BuildContext context, String label, double scale, bool isDark) {
    final isSelected = (_fontScale == scale);
    return InkWell(
      onTap: () {
        setState(() => _fontScale = scale);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.canaryYellow : const Color(0xFF141416))
              : (isDark ? const Color(0xFF1F232D) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? (isDark ? const Color(0xFF141416) : Colors.white)
                : (isDark ? Colors.white : const Color(0xFF141416)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final articleAsync = ref.watch(articleContentProvider(widget.paperId));

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1115) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: Text(
          widget.title ?? 'Article Reader',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        actions: [
          IconButton(
            tooltip: 'Text Size',
            icon: const Icon(Icons.format_size_rounded, size: 20),
            onPressed: () => _showFontSizeSelector(context),
          ),
          articleAsync.maybeWhen(
            data: (article) => article.sections.isNotEmpty
                ? IconButton(
                    tooltip: 'Table of Contents',
                    icon: const Icon(Icons.toc_rounded, size: 22),
                    onPressed: () => _showTableOfContents(context, article),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          IconButton(
            tooltip: 'Ask AI',
            icon: Icon(
              Icons.auto_awesome_rounded,
              color: isDark ? AppTheme.canaryYellow : const Color(0xFF141416),
              size: 20,
            ),
            onPressed: () {
              final encodedTitle =
                  Uri.encodeComponent(widget.title ?? 'Paper');
              context.push(
                  '/papers/${widget.paperId}/chat?title=$encodedTitle');
            },
          ),
        ],
      ),
      body: articleAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Extracting & formatting article text…',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 44, color: Color(0xFFEF4444)),
                const SizedBox(height: 12),
                Text(
                  'Unable to load reader view',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      ref.invalidate(articleContentProvider(widget.paperId)),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (article) {
          if (article.sections.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.article_outlined,
                        size: 48, color: Color(0xFF9CA3AF)),
                    const SizedBox(height: 14),
                    Text(
                      'No full-text sections available yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This paper may be paywalled or currently indexing. You can still read the abstract below or ask Athena AI.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    ),
                    if (article.abstractText.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF161922)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          article.abstractText,
                          style: const TextStyle(fontSize: 13.5, height: 1.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          return ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
            children: [
              // Header Badge & Title
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E222D)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2E3444)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          article.format == 'pdf'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.language_rounded,
                          size: 13,
                          color: isDark
                              ? AppTheme.canaryYellow
                              : const Color(0xFF141416),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          article.format == 'pdf'
                              ? 'PDF EXTRACTED'
                              : 'WEB ARTICLE EXTRACTED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: isDark
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF374151),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (article.sourceUrl.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          launchUrl(Uri.parse(article.sourceUrl)),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text('Original Web',
                          style: TextStyle(fontSize: 11.5)),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                article.title,
                style: TextStyle(
                  fontSize: 20 * _fontScale,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),

              if (article.abstractText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF181B23)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF282E3C)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ABSTRACT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isDark
                              ? AppTheme.canaryYellow
                              : const Color(0xFF141416),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        article.abstractText,
                        style: TextStyle(
                          fontSize: 13.5 * _fontScale,
                          height: 1.5,
                          color: isDark
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Sections rendering
              for (var i = 0; i < article.sections.length; i++) ...[
                Builder(builder: (context) {
                  final section = article.sections[i];
                  _sectionKeys[i] = GlobalKey();
                  return Container(
                    key: _sectionKeys[i],
                    margin: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (section.heading.isNotEmpty ||
                            section.sectionPath.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              section.displayTitle,
                              style: TextStyle(
                                fontSize: 16 * _fontScale,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppTheme.canaryYellow
                                    : const Color(0xFF141416),
                              ),
                            ),
                          ),
                        AiFormattedText(
                          text: section.content,
                          baseStyle: TextStyle(
                            fontSize: 14 * _fontScale,
                            height: 1.55,
                            color: isDark
                                ? const Color(0xFFE5E7EB)
                                : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121419) : Colors.white,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? const Color(0xFF262A36)
                  : const Color(0xFFE5E7EB),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  final encodedTitle =
                      Uri.encodeComponent(widget.title ?? 'Paper');
                  context.push(
                      '/papers/${widget.paperId}/chat?title=$encodedTitle');
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text(
                  'Ask AI about this Paper',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark
                      ? AppTheme.canaryYellow
                      : const Color(0xFF141416),
                  foregroundColor:
                      isDark ? const Color(0xFF141416) : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
