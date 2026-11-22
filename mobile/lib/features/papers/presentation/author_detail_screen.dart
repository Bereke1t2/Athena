import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/athena_top_bar.dart';
import '../../../core/widgets/dot_grid_background.dart';
import '../../../core/widgets/paper_card.dart';
import '../../follows/presentation/follows_notifier.dart';
import 'author_detail_notifier.dart';

/// Screen presenting an author's scholarly profile, impact metrics, and catalog of publications.
class AuthorDetailScreen extends ConsumerWidget {
  const AuthorDetailScreen({
    super.key,
    required this.id,
    this.initialName,
  });

  final String id;
  final String? initialName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.athenaColors;
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(authorDetailProvider(id));
    final notifier = ref.read(authorDetailProvider(id).notifier);
    final follows = ref.watch(followsNotifierProvider);

    final displayName = state.author?.displayName.isNotEmpty == true
        ? state.author!.displayName
        : (initialName ?? 'Author Profile');

    final isFollowing = follows.isAuthorFollowed(id);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AthenaTopBar(
        title: displayName,
      ),
      body: DotGridBackground(
        child: RefreshIndicator(
          onRefresh: notifier.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Author Hero Profile Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surfaceBase,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: AppTheme.coral,
                              child: Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF141416),
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.2,
                                    ),
                                  ),
                                  if (state.author?.affiliations.isNotEmpty == true) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      state.author!.affiliations.join(' · '),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                  if (state.author?.orcid != null && state.author!.orcid!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFA6C8E0).withAlpha(38),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'ORCID: ${state.author!.orcid}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF60A5FA),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Follow Toggle Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing
                                  ? (isDark ? const Color(0xFF262B38) : const Color(0xFFE5E7EB))
                                  : AppTheme.coral,
                              foregroundColor: isFollowing
                                  ? (isDark ? Colors.white : const Color(0xFF141416))
                                  : const Color(0xFF141416),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              ref.read(followsNotifierProvider.notifier).toggleAuthorFollow(id, displayName);
                            },
                            icon: Icon(isFollowing ? Icons.check_rounded : Icons.add_rounded, size: 18),
                            label: Text(
                              isFollowing ? 'Following' : 'Follow Author',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Scholarly Metrics Strip
                        Row(
                          children: [
                            Expanded(
                              child: _MetricBox(
                                label: 'Publications',
                                value: '${state.author?.paperCount ?? state.totalWorks}',
                                icon: Icons.description_outlined,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MetricBox(
                                label: 'Citations',
                                value: _formatNumber(state.author?.citationCount ?? 0),
                                icon: Icons.format_quote_rounded,
                                isDark: isDark,
                              ),
                            ),
                            if (state.author?.hIndex != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _MetricBox(
                                  label: 'H-Index',
                                  value: '${state.author!.hIndex}',
                                  icon: Icons.insights_rounded,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Works Catalog Header with Sort Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'WORKS CATALOG (${state.totalWorks > 0 ? state.totalWorks : state.works.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: isDark ? AppTheme.coral : const Color(0xFF111827),
                        ),
                      ),
                      // Sort Choice Chips
                      Row(
                        children: [
                          _SortChip(
                            label: 'Citations',
                            isSelected: state.sort == 'citations',
                            onTap: () => notifier.setSort('citations'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _SortChip(
                            label: 'Newest',
                            isSelected: state.sort == 'recent',
                            onTap: () => notifier.setSort('recent'),
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _SortChip(
                            label: 'Title',
                            isSelected: state.sort == 'title',
                            onTap: () => notifier.setSort('title'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Works List
              if (state.isLoading && state.works.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.works.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            size: 42,
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No cataloged publications yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Papers linked to this author in Athena\'s research graph will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final paper = state.works[index];
                      return PaperCard(
                        paper: paper,
                        onTap: () => context.push('/papers/${paper.id}'),
                      );
                    },
                    childCount: state.works.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatNumber(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222E) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.coral),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.coral
              : (isDark ? const Color(0xFF1E222E) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? const Color(0xFF141416)
                : (isDark ? Colors.white70 : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }
}
