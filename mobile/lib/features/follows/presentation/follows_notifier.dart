import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../../core/prefs/prefs_providers.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../topics/domain/topic.dart';
import '../domain/follow_models.dart';
import '../domain/follows_repository.dart';

class FollowsState {
  const FollowsState({
    this.followedTopics = const [],
    this.followedAuthors = const [],
    this.isLoading = false,
    this.isGuest = false,
  });

  final List<TopicFollow> followedTopics;
  final List<AuthorFollow> followedAuthors;
  final bool isLoading;
  final bool isGuest;

  bool isTopicFollowed(String slug) =>
      followedTopics.any((t) => t.topicSlug.toLowerCase() == slug.toLowerCase());

  bool isAuthorFollowed(String authorId) =>
      followedAuthors.any((a) => a.authorId == authorId);

  FollowsState copyWith({
    List<TopicFollow>? followedTopics,
    List<AuthorFollow>? followedAuthors,
    bool? isLoading,
    bool? isGuest,
  }) {
    return FollowsState(
      followedTopics: followedTopics ?? this.followedTopics,
      followedAuthors: followedAuthors ?? this.followedAuthors,
      isLoading: isLoading ?? this.isLoading,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

final followsNotifierProvider =
    StateNotifierProvider<FollowsNotifier, FollowsState>((ref) {
  final repo = ref.watch(followsRepositoryProvider);
  final auth = ref.watch(authNotifierProvider);
  final selectedTopics = ref.watch(selectedTopicsProvider);
  return FollowsNotifier(
    repo,
    auth.isAuthenticated,
    guestTopicSlugs: selectedTopics,
    onGuestTopicsChanged: (slugs) {
      ref.read(selectedTopicsProvider.notifier).replace(slugs);
    },
  );
});

class FollowsNotifier extends StateNotifier<FollowsState> {
  FollowsNotifier(
    this._repo,
    this._isAuthenticated, {
    List<String> guestTopicSlugs = const [],
    this.onGuestTopicsChanged,
  }) : super(FollowsState(
          isGuest: !_isAuthenticated,
          followedTopics: !_isAuthenticated
              ? guestTopicSlugs
                  .map((slug) => TopicFollow(
                        topicId: slug,
                        topicSlug: slug,
                        topicName: Topic.displayNameForSlug(slug),
                        notify: true,
                        createdAt: DateTime.now(),
                      ))
                  .toList()
              : const [],
        )) {
    if (_isAuthenticated) {
      loadAll(guestSlugsToSync: guestTopicSlugs);
    }
  }

  final FollowsRepository _repo;
  final bool _isAuthenticated;
  final void Function(List<String>)? onGuestTopicsChanged;

  Future<void> loadAll({List<String>? guestSlugsToSync}) async {
    if (!_isAuthenticated) return;
    state = state.copyWith(isLoading: true);
    try {
      if (guestSlugsToSync != null && guestSlugsToSync.isNotEmpty) {
        for (final slug in guestSlugsToSync) {
          try {
            await _repo.followTopic(slug);
          } catch (_) {
            // Ignore duplicate or individual sync hiccups
          }
        }
      }
      final topics = await _repo.getFollowedTopics();
      final authors = await _repo.getFollowedAuthors();
      state = state.copyWith(
        followedTopics: topics,
        followedAuthors: authors,
        isLoading: false,
        isGuest: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleTopicFollow(String slug, String name) async {
    final cleanSlug = slug.trim().toLowerCase();
    final displayName = name.trim().isNotEmpty ? name.trim() : Topic.displayNameForSlug(slug);

    if (!_isAuthenticated) {
      // Guest researcher: toggle locally in preferences
      final exists = state.isTopicFollowed(cleanSlug);
      List<TopicFollow> updated;
      if (exists) {
        updated = state.followedTopics
            .where((t) => t.topicSlug.toLowerCase() != cleanSlug)
            .toList();
      } else {
        final newFollow = TopicFollow(
          topicId: cleanSlug,
          topicSlug: cleanSlug,
          topicName: displayName,
          notify: true,
          createdAt: DateTime.now(),
        );
        updated = [...state.followedTopics, newFollow];
      }
      state = state.copyWith(followedTopics: updated);
      final newSlugs = updated.map((t) => t.topicSlug).toList();
      onGuestTopicsChanged?.call(newSlugs);
      return;
    }

    // Authenticated account
    final currentlyFollowed = state.isTopicFollowed(cleanSlug);
    if (currentlyFollowed) {
      // Optimistic update
      state = state.copyWith(
        followedTopics: state.followedTopics
            .where((t) => t.topicSlug.toLowerCase() != cleanSlug)
            .toList(),
      );
      try {
        await _repo.unfollowTopic(cleanSlug);
      } catch (_) {
        await loadAll();
      }
    } else {
      final placeholder = TopicFollow(
        topicId: cleanSlug,
        topicSlug: cleanSlug,
        topicName: displayName,
        notify: true,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        followedTopics: [...state.followedTopics, placeholder],
      );
      try {
        final real = await _repo.followTopic(cleanSlug);
        state = state.copyWith(
          followedTopics: state.followedTopics
              .map((t) => t.topicSlug.toLowerCase() == cleanSlug ? real : t)
              .toList(),
        );
      } catch (_) {
        await loadAll();
      }
    }
  }

  Future<void> toggleAuthorFollow(String authorId, String name) async {
    if (!_isAuthenticated) return;
    final currentlyFollowed = state.isAuthorFollowed(authorId);
    if (currentlyFollowed) {
      state = state.copyWith(
        followedAuthors: state.followedAuthors.where((a) => a.authorId != authorId).toList(),
      );
      try {
        await _repo.unfollowAuthor(authorId);
      } catch (_) {
        await loadAll();
      }
    } else {
      final placeholder = AuthorFollow(
        authorId: authorId,
        authorName: name,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        followedAuthors: [...state.followedAuthors, placeholder],
      );
      try {
        final real = await _repo.followAuthor(authorId);
        state = state.copyWith(
          followedAuthors: state.followedAuthors.map((a) => a.authorId == authorId ? real : a).toList(),
        );
      } catch (_) {
        await loadAll();
      }
    }
  }
}
