import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../domain/storage_models.dart';
import 'storage_notifier.dart';

/// Screen managing local device storage, offline cached PDFs, and flight packs.
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  Future<void> _confirmClear(
    BuildContext context, {
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.athenaColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(storageNotifierProvider);
    final notifier = ref.read(storageNotifierProvider.notifier);
    final borderColor = colors.borderSubtle;
    final cardBg = colors.surfaceBase;

    // Listen to messages or errors
    ref.listen<StorageState>(storageNotifierProvider, (_, next) {
      if (next.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message!),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    });

    final b = state.breakdown;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AthenaTopBar(
        title: 'Downloads & Storage',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Storage',
            onPressed: () => notifier.load(),
          ),
        ],
      ),
      body: DotGridBackground(
        child: state.isLoading && state.cachedPdfs.isEmpty
            ? const Center(child: CircularProgressIndicator(color: AppTheme.coral))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Batch Download Flight Pack Progress
                  if (state.batchDownloadProgress != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.coral),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flight_takeoff_rounded,
                                  color: AppTheme.coral, size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Downloading Offline Flight Pack…',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF111827),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${state.batchDownloadProgress!.$1} / ${state.batchDownloadProgress!.$2}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.coral,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: state.batchDownloadProgress!.$2 > 0
                                ? state.batchDownloadProgress!.$1 /
                                    state.batchDownloadProgress!.$2
                                : null,
                            color: AppTheme.coral,
                            backgroundColor: isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Storage Summary Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.coral.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sd_storage_rounded,
                                  color: AppTheme.coral, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'OFFLINE RESEARCH STORAGE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: isDark ? AppTheme.coral : const Color(0xFF141416),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    b.formattedTotalSize,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats Grid
                        Row(
                          children: [
                            Expanded(
                              child: _StatBox(
                                label: 'PDF PAPERS',
                                value: '${b.pdfCount}',
                                subValue: b.formattedPdfSize,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatBox(
                                label: 'SEARCH CACHE',
                                value: '${b.searchHistoryCount}',
                                subValue: 'Queries',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _StatBox(
                                label: 'ANNOTATIONS',
                                value: '${b.annotationsCount}',
                                subValue: 'Papers',
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Maintenance Actions
                  Text(
                    'STORAGE ACTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf_outlined, color: AppTheme.coral),
                          title: const Text('Clear All Cached PDFs',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          subtitle: Text('Removes all downloaded PDF documents (${b.formattedPdfSize})',
                              style: const TextStyle(fontSize: 11.5)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: b.pdfCount == 0
                              ? null
                              : () => _confirmClear(
                                    context,
                                    title: 'Clear Cached PDFs?',
                                    content:
                                        'This will remove all ${b.pdfCount} downloaded PDF files from your device. They can be re-downloaded at any time.',
                                    onConfirm: () => notifier.clearAllPdfs(),
                                  ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.history_rounded, color: Color(0xFF3B82F6)),
                          title: const Text('Clear Search Query History',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          subtitle: Text('${b.searchHistoryCount} recent queries stored',
                              style: const TextStyle(fontSize: 11.5)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: b.searchHistoryCount == 0
                              ? null
                              : () => _confirmClear(
                                    context,
                                    title: 'Clear Search History?',
                                    content: 'This will reset your recent search queries cache.',
                                    onConfirm: () => notifier.clearSearchHistory(),
                                  ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
                          title: const Text('Reset All Local Storage',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFFEF4444))),
                          subtitle: const Text('Clear both cached PDFs and search query caches',
                              style: TextStyle(fontSize: 11.5)),
                          trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: (b.pdfCount == 0 && b.searchHistoryCount == 0)
                              ? null
                              : () => _confirmClear(
                                    context,
                                    title: 'Reset Local Storage?',
                                    content:
                                        'This will erase all cached PDFs and query histories. Saved bookmarks and account data remain intact.',
                                    onConfirm: () => notifier.clearAllStorage(),
                                  ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Offline Cached Papers List
                  Row(
                    children: [
                      Text(
                        'OFFLINE PAPERS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF232734) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          '${state.cachedPdfs.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (state.cachedPdfs.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.offline_pin_outlined,
                            size: 40,
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Offline Papers Cached',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Papers you open in the PDF reader or save for offline flight study will be listed here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: state.cachedPdfs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, index) {
                        final file = state.cachedPdfs[index];
                        final formattedSize = formatStorageBytes(file.sizeBytes);

                        return Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.coral.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: AppTheme.coral,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              'Paper ${file.paperId}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              '$formattedSize · Cached ${file.modifiedAt.month}/${file.modifiedAt.day}/${file.modifiedAt.year}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  tooltip: 'Open PDF',
                                  onPressed: () {
                                    context.push('/papers/${file.paperId}/pdf?url=&title=Paper%20${file.paperId}');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                  tooltip: 'Remove',
                                  onPressed: () => notifier.deletePdf(file.paperId),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.subValue,
    required this.isDark,
  });

  final String label;
  final String value;
  final String subValue;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E212B) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2B303E) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            subValue,
            style: TextStyle(
              fontSize: 10.5,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
