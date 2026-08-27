import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/papers/domain/paper.dart';
import 'state_views.dart';

/// Card tile for a paper summary; used by feed/search/topic lists.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.paper, this.onTap, this.badge});

  final PaperSummary paper;
  final VoidCallback? onTap;

  /// Optional leading-edge badge (e.g. relevance score in search results).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final abstractText = paper.abstract;
    final venue = paper.venueName.isEmpty
        ? paper.publicationType.replaceAll('_', ' ')
        : paper.venueName;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      paper.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (badge != null) ...[const SizedBox(width: 8), badge!],
                ],
              ),
              if (abstractText != null && abstractText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  abstractText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        venue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Meta(icon: Icons.calendar_today_outlined, label: '${paper.year}'),
                  const SizedBox(width: 10),
                  _Meta(icon: Icons.format_quote_rounded, label: _count(paper.citedByCount)),
                  if (paper.isOpenAccess) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_open_rounded,
                            size: 11,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'OA',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _count(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k'
      : '$n';
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Generic list view over an [AsyncValue] of a list, rendering the four
/// canonical states (loading/error/empty/content) plus an optional
/// load-more footer driven by scroll position.
class AsyncListView<T> extends StatefulWidget {
  const AsyncListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    this.emptySubtitle,
    this.onRetry,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.onRefresh,
    this.footerVisible = true,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext, T item) itemBuilder;
  final IconData emptyIcon;
  final String emptyTitle;
  final String? emptySubtitle;
  final VoidCallback? onRetry;

  /// Called once when the list end scrolls into view.
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final Future<void> Function()? onRefresh;

  /// Show the load-more footer slot at all (false when no next cursor).
  final bool footerVisible;

  @override
  State<AsyncListView<T>> createState() => _AsyncListViewState<T>();
}

class _AsyncListViewState<T> extends State<AsyncListView<T>> {
  var _loadMoreRequested = false;

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      loading: () => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 6,
        itemBuilder: (context, i) => const _SkeletonCard(),
      ),
      error: (e, _) => ErrorView(failure: e, onRetry: widget.onRetry),
      data: (items) {
        if (items.isEmpty) {
          return EmptyView(
            icon: widget.emptyIcon,
            title: widget.emptyTitle,
            subtitle: widget.emptySubtitle,
          );
        }
        final showFooter = widget.footerVisible && widget.onLoadMore != null;
        final body = ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: items.length + (showFooter ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == items.length) {
              if (!_loadMoreRequested && !widget.isLoadingMore) {
                _loadMoreRequested = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _loadMoreRequested = false;
                  widget.onLoadMore?.call();
                });
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: widget.isLoadingMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            }
            return widget.itemBuilder(context, items[i]);
          },
        );
        if (widget.onRefresh == null) return body;
        return RefreshIndicator(onRefresh: widget.onRefresh!, child: body);
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shade = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: shade, borderRadius: BorderRadius.circular(6)),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(double.infinity, 16),
            const SizedBox(height: 8),
            FractionallySizedBox(
              widthFactor: 0.6,
              alignment: Alignment.centerLeft,
              child: bar(double.infinity, 16),
            ),
            const SizedBox(height: 12),
            FractionallySizedBox(
              widthFactor: 0.4,
              alignment: Alignment.centerLeft,
              child: bar(double.infinity, 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontal Featured Hero Card matching the reference image layout.
class FeaturedPaperCard extends StatelessWidget {
  const FeaturedPaperCard({super.key, required this.paper, this.onTap});

  final PaperSummary paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Cover Thumbnail Graphic
              Container(
                width: 90,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [theme.colorScheme.primary, theme.colorScheme.tertiary]
                        : [const Color(0xFF4C5BD4), const Color(0xFF8C52FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${paper.year}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            paper.publicationType.replaceAll('_', ' ').toUpperCase(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Paper Content & Author Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Row (matching reference image author pill)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.person_rounded,
                            size: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            paper.venueName.isNotEmpty ? paper.venueName : 'Researcher',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Title
                    Text(
                      paper.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        fontSize: 14,
                      ),
                    ),
                    if (paper.abstract != null && paper.abstract!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        paper.abstract!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical Cover Card matching the bottom carousel in the reference image.
class TopPaperCoverCard extends StatelessWidget {
  const TopPaperCoverCard({super.key, required this.paper, this.onTap});

  final PaperSummary paper;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Art Container (3:4 ratio)
            Container(
              height: 130,
              width: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: isDark
                      ? [theme.colorScheme.secondary, theme.colorScheme.primary]
                      : [const Color(0xFF3F51B5), const Color(0xFF00BCD4)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -10,
                    left: -10,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (paper.isOpenAccess)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'OA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Text(
                          paper.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              paper.venueName.isNotEmpty ? paper.venueName : '${paper.year}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
