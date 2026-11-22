import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/annotation.dart';
import '../annotations_notifier.dart';

/// Centralized view for browsing, filtering, and exporting text highlights and notes across papers.
class HighlightsTabView extends ConsumerStatefulWidget {
  const HighlightsTabView({super.key});

  @override
  ConsumerState<HighlightsTabView> createState() => _HighlightsTabViewState();
}

class _HighlightsTabViewState extends ConsumerState<HighlightsTabView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportAllToMarkdown(List<UserAnnotation> items) {
    if (items.isEmpty) return;

    final buffer = StringBuffer('# Athena Research Highlights\n\n');
    buffer.writeln('Exported ${items.length} annotations on ${DateTime.now().toLocal().toString().split('.').first}\n');

    for (final item in items) {
      buffer.writeln('### ${item.paperTitle}');
      final meta = [
        if (item.paperVenue.isNotEmpty) item.paperVenue,
        if (item.paperYear != null) '${item.paperYear}',
        'Page ${item.pageNumber}',
      ].join(' · ');
      if (meta.isNotEmpty) buffer.writeln('*$meta*\n');
      buffer.writeln('> ${item.selectedText}\n');
      if (item.note.isNotEmpty) {
        buffer.writeln('**Note**: ${item.note}\n');
      }
      buffer.writeln('---\n');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported highlights copied to clipboard as Markdown'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(userAnnotationsProvider);
    final notifier = ref.read(userAnnotationsProvider.notifier);

    return Column(
      children: [
        // Search & Filter Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222D) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search highlights & margin notes...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              notifier.setSearchQuery('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (val) => notifier.setSearchQuery(val.trim()),
                ),
              ),

              const SizedBox(height: 10),

              // Color filter chips & Export button
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('All'),
                            selected: state.selectedColor == null || state.selectedColor!.isEmpty,
                            onSelected: (_) => notifier.setColorFilter(null),
                            selectedColor: AppTheme.coral.withAlpha(51),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: state.selectedColor == null || state.selectedColor!.isEmpty
                                  ? AppTheme.coral
                                  : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ...AnnotationColor.values.map((col) {
                            final isSelected = state.selectedColor == col.code;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: CircleAvatar(
                                  radius: 6,
                                  backgroundColor: Color(col.colorHex),
                                ),
                                label: Text(col.label),
                                selected: isSelected,
                                selectedColor: Color(col.tintHex),
                                onSelected: (_) => notifier.setColorFilter(col.code),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? Colors.white : const Color(0xFF111827))
                                      : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  if (state.items.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, size: 20),
                      tooltip: 'Export Markdown',
                      onPressed: () => _exportAllToMarkdown(state.items),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Body Content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => notifier.refresh(),
            child: state.isLoading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.items.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(22),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1F232D) : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_note_rounded,
                                  size: 40,
                                  color: AppTheme.coral,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                state.searchQuery.isNotEmpty || (state.selectedColor != null && state.selectedColor!.isNotEmpty)
                                    ? 'No matching highlights'
                                    : 'No highlights saved yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                state.searchQuery.isNotEmpty || (state.selectedColor != null && state.selectedColor!.isNotEmpty)
                                    ? 'Try clearing your color filter or adjusting your search keywords.'
                                    : 'Select text while reading papers to highlight key passages and add margin notes.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: state.items.length,
                        itemBuilder: (context, i) {
                          final item = state.items[i];
                          final borderCol = Color(item.color.colorHex);
                          final bgTint = Color(item.color.tintHex);

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isDark ? const Color(0xFF282C38) : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Paper Title & Metadata
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => context.push('/papers/${item.paperId}'),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.paperTitle.isNotEmpty
                                                ? item.paperTitle
                                                : 'Research Paper',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                                      ],
                                    ),
                                  ),

                                  if (item.paperVenue.isNotEmpty || item.paperYear != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        if (item.paperVenue.isNotEmpty) item.paperVenue,
                                        if (item.paperYear != null) '${item.paperYear}',
                                      ].join(' · '),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // Highlighted Text Block
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: bgTint,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(
                                        left: BorderSide(color: borderCol, width: 4),
                                      ),
                                    ),
                                    child: Text(
                                      item.selectedText,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.5,
                                        color: isDark ? Colors.white : const Color(0xFF1E222D),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),

                                  // Margin Note (if any)
                                  if (item.note.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF181B22) : const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.edit_note_rounded,
                                            size: 16,
                                            color: isDark ? AppTheme.coral : const Color(0xFF111827),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.note,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                height: 1.4,
                                                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF374151),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 10),

                                  // Footer: Page / Section & Action buttons
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF232733) : const Color(0xFFF3F4F6),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Page ${item.pageNumber}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      // Copy button
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded, size: 16),
                                        tooltip: 'Copy quote',
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: item.selectedText));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Quote copied to clipboard'),
                                              duration: Duration(seconds: 2),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                      ),
                                      // Delete button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                        tooltip: 'Delete highlight',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete highlight?'),
                                              content: const Text('Are you sure you want to remove this highlight and note?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Delete', style: TextStyle(color: Color(0xFFFF7675))),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await notifier.deleteAnnotation(item.id, item.paperId);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}
