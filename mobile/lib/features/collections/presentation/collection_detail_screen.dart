import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import 'collections_notifier.dart';

class CollectionDetailScreen extends ConsumerStatefulWidget {
  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  final String collectionId;

  @override
  ConsumerState<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends ConsumerState<CollectionDetailScreen> {
  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  void _showExportSheet(BuildContext context, String collectionName) {
    String selectedFormat = 'bibtex';
    bool isExporting = false;
    String? exportedContent;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222D) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppTheme.coral, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Export Bibliography',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Export all papers in "$collectionName" to citation formats.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'FORMAT',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['bibtex', 'ris', 'apa', 'mla', 'markdown'].map((fmt) {
                      final isSelected = selectedFormat == fmt;
                      return ChoiceChip(
                        label: Text(fmt.toUpperCase()),
                        selected: isSelected,
                        selectedColor: AppTheme.coral.withAlpha(40),
                        labelStyle: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppTheme.coral : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        onSelected: (val) {
                          if (val) {
                            setSheetState(() {
                              selectedFormat = fmt;
                              exportedContent = null;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  if (exportedContent != null) ...[
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14171F) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          exportedContent!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy to Clipboard'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: exportedContent!));
                          Navigator.of(sheetCtx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bibliography copied to clipboard')),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.coral),
                        icon: isExporting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.download_rounded, size: 16),
                        label: Text(isExporting ? 'Generating...' : 'Generate Citation'),
                        onPressed: isExporting
                            ? null
                            : () async {
                                setSheetState(() => isExporting = true);
                                try {
                                  final content = await ref
                                      .read(collectionDetailProvider(widget.collectionId).notifier)
                                      .exportCitations(format: selectedFormat);
                                  setSheetState(() {
                                    isExporting = false;
                                    exportedContent = content;
                                  });
                                } catch (e) {
                                  setSheetState(() => isExporting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Export failed: $e')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(collectionDetailProvider(widget.collectionId));

    return state.when(
      loading: () => Scaffold(
        backgroundColor: isDark ? AppTheme.deepDark : AppTheme.lightBg,
        appBar: const AthenaTopBar(title: 'Collection', showLeading: true),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.coral)),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: isDark ? AppTheme.deepDark : AppTheme.lightBg,
        appBar: const AthenaTopBar(title: 'Collection', showLeading: true),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.coral, size: 40),
              const SizedBox(height: 12),
              Text(
                'Collection Not Found',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Library'),
              ),
            ],
          ),
        ),
      ),
      data: (data) {
        final col = data.collection;
        final papers = data.papers;
        final colColor = _parseHex(col.color);

        return Scaffold(
          backgroundColor: isDark ? AppTheme.deepDark : AppTheme.lightBg,
          appBar: AthenaTopBar(
            title: col.name,
            showLeading: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                tooltip: 'Export Citations',
                onPressed: () => _showExportSheet(context, col.name),
              ),
            ],
          ),
          body: DotGridBackground(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                // Collection Header Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF181B22) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF242834) : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: colColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            col.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const Spacer(),
                          if (col.isPublic)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Public',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (col.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          col.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${papers.length} ${papers.length == 1 ? "paper" : "papers"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563),
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: AppTheme.coral,
                            ),
                            icon: const Icon(Icons.share_outlined, size: 14),
                            label: const Text('Export', style: TextStyle(fontSize: 12)),
                            onPressed: () => _showExportSheet(context, col.name),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section Label
                Text(
                  'PAPERS IN COLLECTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: isDark ? AppTheme.coral : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),

                if (papers.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF181B22) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF242834) : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.post_add_rounded,
                          size: 36,
                          color: isDark ? const Color(0xFF4B5563) : const Color(0xFF9CA3AF),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No papers in this collection',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Open any research paper and tap the collection icon to add it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...papers.map((cp) {
                    final paper = cp.paper;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: isDark ? const Color(0xFF181B22) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => context.push('/papers/${paper.id}'),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF242834) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        paper.title,
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                                      color: Colors.red.withAlpha(200),
                                      tooltip: 'Remove from collection',
                                      onPressed: () async {
                                        await ref
                                            .read(collectionDetailProvider(widget.collectionId).notifier)
                                            .removePaper(paper.id);
                                        await ref.read(collectionsProvider.notifier).load();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${paper.venueName.isNotEmpty ? paper.venueName : "Research"} · ${paper.year > 0 ? paper.year : "Recent"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  ),
                                ),
                                if (cp.note.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: colColor.withAlpha(20),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: colColor.withAlpha(50)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_note_rounded, size: 14, color: colColor),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            cp.note,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}
