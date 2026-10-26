import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di.dart';
import '../../../core/prefs/prefs_providers.dart';
import '../domain/feed.dart';

part 'feed_notifier.g.dart';
part 'feed_notifier.freezed.dart';

/// The active topic filter on the discovery feed. Defaults to 'all' so users see
/// the full discovery feed across Athena; specific topic slugs filter accordingly.
final activeTopicFilterProvider = StateProvider<String>((ref) => 'all');

/// Pagination state per conventions: {items, cursor, loadingMore}; top-level
/// async states ride on the AsyncValue wrapper.
@freezed
sealed class FeedPageState with _$FeedPageState {
  const factory FeedPageState({
    required List<FeedItem> items,
    String? cursor,
    @Default(false) bool loadingMore,
  }) = _FeedPageState;
}

/// Feed for one section, filtered by the active topic filter or onboarding interests.
/// Watches [activeTopicFilterProvider] and [selectedTopicsProvider], so switching filters
/// refreshes automatically.
@riverpod
class FeedNotifier extends _$FeedNotifier {
  @override
  Future<FeedPageState> build(FeedSection section) async {
    final activeFilter = ref.watch(activeTopicFilterProvider);
    List<String> topics;
    if (activeFilter == 'all') {
      topics = const [];
    } else if (activeFilter.isNotEmpty) {
      topics = [activeFilter];
    } else {
      topics = ref.watch(selectedTopicsProvider);
    }

    final page = await ref.watch(feedRepositoryProvider).load(
          section: section,
          topics: topics,
          limit: Paging.defaultLimit,
        );
    return FeedPageState(items: page.items, cursor: page.nextCursor);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || current.cursor == null) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final activeFilter = ref.read(activeTopicFilterProvider);
      List<String> topics;
      if (activeFilter == 'all') {
        topics = const [];
      } else if (activeFilter.isNotEmpty) {
        topics = [activeFilter];
      } else {
        topics = ref.read(selectedTopicsProvider);
      }

      final page = await ref.read(feedRepositoryProvider).load(
            section: section,
            topics: topics,
            cursor: current.cursor,
            limit: Paging.defaultLimit,
          );
      final updated = current.copyWith(
        items: [...current.items, ...page.items],
        cursor: page.nextCursor,
        loadingMore: false,
      );
      state = AsyncData(updated);
    } catch (e, st) {
      // Keep existing items; surface the error only when we have none.
      if (current.items.isEmpty) {
        state = AsyncError(e, st);
      } else {
        state = AsyncData(current.copyWith(loadingMore: false));
      }
    }
  }
}
