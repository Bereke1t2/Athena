import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di.dart';
import '../domain/topic.dart';
import '../domain/topics_repository.dart';

part 'topics_notifier.freezed.dart';
part 'topics_notifier.g.dart';

@freezed
sealed class TopicListState with _$TopicListState {
  const factory TopicListState({
    required List<Topic> items,
    String? cursor,
    @Default('') String kindFilter,
    @Default(false) bool loadingMore,
  }) = _TopicListState;
}

@riverpod
class TopicListNotifier extends _$TopicListNotifier {
  @override
  Future<TopicListState> build() async {
    final page = await ref.watch(topicsRepositoryProvider).list(limit: Paging.defaultLimit);
    return TopicListState(items: page.items, cursor: page.nextCursor);
  }

  Future<void> setKind(String kind) async {
    if (kind == state.valueOrNull?.kindFilter) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final page = await ref.read(topicsRepositoryProvider).list(
            kind: kind.isEmpty ? null : kind,
            limit: Paging.defaultLimit,
          );
      return TopicListState(items: page.items, cursor: page.nextCursor, kindFilter: kind);
    });
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.cursor == null || current.loadingMore) return;

    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(topicsRepositoryProvider).list(
            kind: current.kindFilter.isEmpty ? null : current.kindFilter,
            cursor: current.cursor,
            limit: Paging.defaultLimit,
          );
      state = AsyncData(current.copyWith(
        items: [...current.items, ...page.items],
        cursor: page.nextCursor,
        loadingMore: false,
      ));
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }
}

@riverpod
class TopicDetailController extends _$TopicDetailController {
  @override
  FutureOr<Topic> build(String slug) {
    return ref.watch(topicsRepositoryProvider).getBySlug(slug);
  }
}

/// Papers filed under one topic (topic detail screen's list).
@riverpod
class TopicPapersNotifier extends _$TopicPapersNotifier {
  @override
  Future<PaperListPage> build(String slug, {String sort = 'relevance'}) async {
    return ref.watch(topicsRepositoryProvider).listResearch(slug, sort: sort);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.nextCursor == null) return;
    try {
      final page = await ref.read(topicsRepositoryProvider).listResearch(
            slug,
            sort: sort,
            cursor: current.nextCursor,
          );
      state = AsyncData(PaperListPage(
        items: [...current.items, ...page.items],
        nextCursor: page.nextCursor,
      ));
    } catch (_) {
      // keep prior content on pagination failure
    }
  }
}
