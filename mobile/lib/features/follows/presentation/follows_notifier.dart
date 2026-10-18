import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/follow_models.dart';
import '../domain/follows_repository.dart';


class FollowsState {
  const FollowsState({
    this.followedTopics = const [],
    this.followedAuthors = const [],
    this.isLoading = false,
  });

  final List<TopicFollow> followedTopics;
  final List<AuthorFollow> followedAuthors;
  final bool isLoading;

  bool isTopicFollowed(String slug) =>
      followedTopics.any((t) => t.topicSlug.toLowerCase() == slug.toLowerCase());

  bool isAuthorFollowed(String authorId) =>
      followedAuthors.any((a) => a.authorId == authorId);

  FollowsState copyWith({
    List<TopicFollow>? followedTopics,
    List<AuthorFollow>? followedAuthors,
    bool? isLoading,
  }) {
    return FollowsState(
      followedTopics: followedTopics ?? this.followedTopics,
      followedAuthors: followedAuthors ?? this.followedAuthors,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final followsNotifierProvider =
    StateNotifierProvider<FollowsNotifier, FollowsState>((ref) {
  final repo = ref.watch(followsRepositoryProvider);
  final auth = ref.watch(authNotifierProvider);
  return FollowsNotifier(repo, auth.isAuthenticated);
});

class FollowsNotifier extends StateNotifier<FollowsState> {
  FollowsNotifier(this._repo, this._isAuthenticated) : super(const FollowsState()) {
    if (_isAuthenticated) {
      loadAll();
    }
  }

  final FollowsRepository _repo;
  final bool _isAuthenticated;

  Future<void> loadAll() async {
    if (!_isAuthenticated) return;
    state = state.copyWith(isLoading: true);
    try {
      final topics = await _repo.getFollowedTopics();
      final authors = await _repo.getFollowedAuthors();
      state = state.copyWith(
        followedTopics: topics,
        followedAuthors: authors,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> toggleTopicFollow(String slug, String name) async {
    if (!_isAuthenticated) return;
    final currentlyFollowed = state.isTopicFollowed(slug);
    if (currentlyFollowed) {
      // Optimistic update
      state = state.copyWith(
        followedTopics: state.followedTopics.where((t) => t.topicSlug.toLowerCase() != slug.toLowerCase()).toList(),
      );
      try {
        await _repo.unfollowTopic(slug);
      } catch (_) {
        await loadAll();
      }
    } else {
      final placeholder = TopicFollow(
        topicId: slug,
        topicSlug: slug,
        topicName: name,
        notify: true,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        followedTopics: [...state.followedTopics, placeholder],
      );
      try {
        final real = await _repo.followTopic(slug);
        state = state.copyWith(
          followedTopics: state.followedTopics.map((t) => t.topicSlug == slug ? real : t).toList(),
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
