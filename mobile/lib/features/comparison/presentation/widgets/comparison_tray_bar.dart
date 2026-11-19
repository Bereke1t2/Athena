import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/comparison_tray_models.dart';
import '../comparison_tray_notifier.dart';

/// Floating docked bar showing the active multi-paper comparison tray.
/// Allows researchers to accumulate up to 4 papers across Feed, Search,
/// Topics, and Collections, and launch comparative analysis with 1 tap.
class ComparisonTrayBar extends ConsumerWidget {
  const ComparisonTrayBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tray = ref.watch(comparisonTrayProvider);
    if (tray.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161922) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: tray.isExpanded
            ? _buildExpandedTray(context, ref, tray, isDark)
            : _buildCollapsedPill(context, ref, tray, isDark),
      ),
    );
  }

  Widget _buildCollapsedPill(
    BuildContext context,
    WidgetRef ref,
    ComparisonTrayState tray,
    bool isDark,
  ) {
    return InkWell(
      onTap: () => ref.read(comparisonTrayProvider.notifier).toggleExpanded(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.coral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                size: 18,
                color: AppTheme.coral,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Compare Papers',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF141416),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.coral.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${tray.count}/4',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.coral,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tray.canCompare
                        ? '${tray.count} papers selected for synthesis'
                        : 'Select 1 more paper to compare',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (tray.canCompare)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  context.push('/compare?ids=${tray.paperIds.join(',')}');
                },
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text(
                  'Compare',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              tooltip: 'Expand comparison tray',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                ref.read(comparisonTrayProvider.notifier).toggleExpanded();
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Clear comparison tray',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                ref.read(comparisonTrayProvider.notifier).clear();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedTray(
    BuildContext context,
    WidgetRef ref,
    ComparisonTrayState tray,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  size: 16,
                  color: AppTheme.coral,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'COMPARISON TRAY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${tray.count}/4',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.coral,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  ref.read(comparisonTrayProvider.notifier).clear();
                },
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                tooltip: 'Collapse comparison tray',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  ref.read(comparisonTrayProvider.notifier).toggleExpanded();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Horizontal Paper Cards
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tray.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = tray.items[index];
                return _buildTrayPaperCard(context, ref, item, isDark);
              },
            ),
          ),
          const SizedBox(height: 12),

          // Footer Action Bar
          Row(
            children: [
              Expanded(
                child: Text(
                  tray.canCompare
                      ? 'Ready to generate comparative matrix and synthesis.'
                      : 'Add at least 1 more paper from search or feed to compare.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.coral,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: tray.canCompare
                    ? () {
                        context.push('/compare?ids=${tray.paperIds.join(',')}');
                      }
                    : null,
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: Text(
                  'Compare (${tray.count})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrayPaperCard(
    BuildContext context,
    WidgetRef ref,
    ComparisonTrayItem item,
    bool isDark,
  ) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2330) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title.isEmpty ? 'Untitled Paper' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isDark ? Colors.white : const Color(0xFF141416),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  ref.read(comparisonTrayProvider.notifier).removePaper(item.paperId);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2E3444) : const Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            [
              if (item.venue.isNotEmpty) item.venue,
              if (item.year > 0) '${item.year}',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}
