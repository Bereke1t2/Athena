import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/annotation.dart';
import '../annotation_colors.dart';
import '../annotations_notifier.dart';
import 'add_annotation_dialog.dart';

/// Modal bottom sheet listing all reader highlights and margin notes on a paper.
class AnnotationsSheet extends ConsumerWidget {
  const AnnotationsSheet({
    super.key,
    required this.paperId,
    this.paperTitle,
  });

  final String paperId;
  final String? paperTitle;

  static Future<void> show(BuildContext context, {required String paperId, String? paperTitle}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161922) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AnnotationsSheet(paperId: paperId, paperTitle: paperTitle),
    );
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AddAnnotationDialog(
        paperId: paperId,
        selectedText: 'Custom margin note on $paperTitle',
        pageNumber: 1,
      ),
    );

    if (res != null) {
      final note = res['note'] as String? ?? '';
      final color = res['color'] as AnnotationColor? ?? AnnotationColor.yellow;
      await ref.read(paperAnnotationsProvider(paperId).notifier).createAnnotation(
        selectedText: 'Margin note: ${note.isNotEmpty ? note : "Key takeaway"}',
        note: note,
        color: color,
        pageNumber: 1,
      );
    }
  }

  Future<void> _openEditDialog(BuildContext context, WidgetRef ref, Annotation annotation) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AddAnnotationDialog(
        paperId: paperId,
        selectedText: annotation.selectedText,
        initialNote: annotation.note,
        initialColor: annotation.color,
        pageNumber: annotation.pageNumber,
        isEditing: true,
      ),
    );

    if (res != null) {
      final note = res['note'] as String?;
      final color = res['color'] as AnnotationColor?;
      await ref.read(paperAnnotationsProvider(paperId).notifier).updateAnnotation(
        id: annotation.id,
        note: note,
        color: color,
      );
    }
  }

  void _askAIAboutAnnotation(BuildContext context, Annotation annotation) {
    Navigator.of(context).pop();
    final prompt = 'Regarding this passage: "${annotation.selectedText}" - could you elaborate on this and explain its implications?';
    final encodedPrompt = Uri.encodeComponent(prompt);
    context.push('/papers/$paperId/chat?initialPrompt=$encodedPrompt');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(paperAnnotationsProvider(paperId));
    final borderColor = isDark ? const Color(0xFF262A36) : const Color(0xFFE5E7EB);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollController) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sheet drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: AppTheme.coral,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'HIGHLIGHTS & MARGIN NOTES',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: isDark ? AppTheme.coral : const Color(0xFF141416),
                                ),
                              ),
                              const SizedBox(width: 8),
                              state.when(
                                data: (items) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF232734) : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            paperTitle ?? 'Paper notes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, size: 24),
                      tooltip: 'Add Margin Note',
                      onPressed: () => _openAddDialog(context, ref),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 1),

              // Content
              Expanded(
                child: state.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.coral),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 36, color: Color(0xFFEF4444)),
                          const SizedBox(height: 8),
                          Text('Failed to load annotations: $err', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => ref.read(paperAnnotationsProvider(paperId).notifier).load(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E212B) : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.edit_note_rounded,
                                  size: 40,
                                  color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No Highlights Yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Select text while reading or tap below to record insights and margin notes.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => _openAddDialog(context, ref),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('Add First Note'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.coral,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, index) {
                        final annotation = items[index];
                        final c = annotation.color;

                        return Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF191D26) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top bar
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: c.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Page ${annotation.pageNumber}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Edit Note',
                                      onPressed: () => _openEditDialog(context, ref, annotation),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        await ref
                                            .read(paperAnnotationsProvider(paperId).notifier)
                                            .deleteAnnotation(annotation.id);
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // Highlight quote block
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: c.tint,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border(
                                      left: BorderSide(color: c.color, width: 3.5),
                                    ),
                                  ),
                                  child: Text(
                                    annotation.selectedText,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ),

                              // Margin note
                              if (annotation.note.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2, right: 6),
                                        child: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 13,
                                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          annotation.note,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            height: 1.35,
                                            color: isDark ? Colors.white : const Color(0xFF111827),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Footer actions: "Ask AI about this"
                              Padding(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    InkWell(
                                      onTap: () => _askAIAboutAnnotation(context, annotation),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppTheme.coral.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.auto_awesome_rounded,
                                              size: 13,
                                              color: AppTheme.coral,
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              'Ask AI about this',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.coral,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
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
}
