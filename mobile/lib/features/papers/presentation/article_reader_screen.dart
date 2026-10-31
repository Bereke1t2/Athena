import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ai_formatted_text.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../../core/widgets/floating_research_prompt_bar.dart';
import '../../history/presentation/history_notifier.dart';
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
  double _lastReportedProgress = 0.0;
  final int _activeCarouselPage = 3;
  final Set<int> _collapsedSections = {};

  static String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _showMoreActions(BuildContext context, ArticleContent? article) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF181A20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.format_size_rounded),
                  title: const Text('Adjust Text Size', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showFontSizeSelector(context);
                  },
                ),
                if (article != null && article.sections.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.toc_rounded),
                    title: const Text('Table of Contents', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showTableOfContents(context, article);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.headphones_outlined),
                  title: const Text('Audio Studio Brief', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final encodedTitle =
                        Uri.encodeComponent(widget.title ?? article?.title ?? 'Paper');
                    context.push(
                        '/create-audio?paperId=${widget.paperId}&title=$encodedTitle');
                  },
                ),
                if (article != null && article.sourceUrl.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: const Text('Original Web Article', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      launchUrl(Uri.parse(article.sourceUrl));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final pct = (_scrollController.position.pixels / max).clamp(0.0, 1.0) * 100.0;
    if ((pct - _lastReportedProgress).abs() >= 10.0 || pct >= 95.0) {
      _lastReportedProgress = pct;
      ref.read(historyNotifierProvider.notifier).recordProgress(widget.paperId, pct);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_lastReportedProgress > 0) {
      ref.read(historyNotifierProvider.notifier).recordProgress(widget.paperId, _lastReportedProgress);
    }
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
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _fontOption(context, 'Small', 0.85, isDark),
                      const SizedBox(width: 8),
                      _fontOption(context, 'Normal', 1.0, isDark),
                      const SizedBox(width: 8),
                      _fontOption(context, 'Large', 1.15, isDark),
                      const SizedBox(width: 8),
                      _fontOption(context, 'Extra', 1.3, isDark),
                    ],
                  ),
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
    final borderColor = isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101216) : const Color(0xFFFBFBFB),
      appBar: AppBar(
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),
        ),
        title: Text(
          'Research Report',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: -0.2,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: InkWell(
                onTap: () => _showMoreActions(context, articleAsync.valueOrNull),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: DotGridBackground(
        child: articleAsync.when(
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.coral),
                SizedBox(height: 16),
                Text(
                  'Synthesizing Research Report…',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
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
                    'Unable to load report',
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
            return Stack(
              children: [
                ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  children: [
                    // Main Research Report Card Container matching the Resarc design
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF181A20) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: borderColor, width: 1.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Carousel page dots (· · · 🔴 ·)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              final isActive = (index == _activeCarouselPage);
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isActive ? 6 : 4,
                                height: isActive ? 6 : 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? AppTheme.coral
                                      : (isDark
                                          ? const Color(0xFF374151)
                                          : const Color(0xFFD1D5DB)),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 16),

                          // Date stamp
                          Text(
                            _formattedDate(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // High-Impact Editorial Research Question / Paper Headline
                          Text(
                            article.title,
                            style: TextStyle(
                              fontSize: 20 * _fontScale,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                              letterSpacing: -0.4,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Lead Takeaway Paragraph
                          if (article.abstractText.isNotEmpty)
                            Text(
                              article.abstractText.length > 180
                                  ? '${article.abstractText.substring(0, 180).trim()}…'
                                  : article.abstractText,
                              style: TextStyle(
                                fontSize: 14 * _fontScale,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                                color: isDark
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          const SizedBox(height: 20),

                          // Coral Uppercase ABSTRACT Header
                          const Text(
                            'ABSTRACT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: AppTheme.coral,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Abstract content with red/coral citation bullet marks
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13.5 * _fontScale,
                                height: 1.55,
                                color: isDark
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF1F2937),
                              ),
                              children: [
                                TextSpan(
                                  text: article.abstractText.isNotEmpty
                                      ? article.abstractText
                                      : 'No abstract available for this paper.',
                                ),
                                const WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.circle,
                                      size: 5,
                                      color: AppTheme.coral,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Sections with interactive collapsible coral headers (METHOD ∨, etc.)
                          for (var i = 0; i < article.sections.length; i++) ...[
                            Builder(builder: (context) {
                              final section = article.sections[i];
                              _sectionKeys[i] = GlobalKey();
                              final isCollapsed = _collapsedSections.contains(i);

                              return Container(
                                key: _sectionKeys[i],
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isCollapsed) {
                                            _collapsedSections.remove(i);
                                          } else {
                                            _collapsedSections.add(i);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              section.displayTitle.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.9,
                                                color: AppTheme.coral,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              isCollapsed
                                                  ? Icons.keyboard_arrow_right_rounded
                                                  : Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: AppTheme.coral,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (!isCollapsed) ...[
                                      const SizedBox(height: 6),
                                      AiFormattedText(
                                        text: section.content,
                                        baseStyle: TextStyle(
                                          fontSize: 13.5 * _fontScale,
                                          height: 1.55,
                                          color: isDark
                                              ? const Color(0xFFE5E7EB)
                                              : const Color(0xFF1F2937),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Floating Universal AI Prompt Bar pinned at the bottom
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: FloatingResearchPromptBar(
                    paperId: widget.paperId,
                    paperTitle: widget.title ?? article.title,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
