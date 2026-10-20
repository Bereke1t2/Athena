import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di.dart';
import 'user_preferences.dart';

part 'saved_papers.g.dart';

/// A saved-paper record persisted locally with server-side sync when authenticated.
class SavedPaper {
  const SavedPaper({
    required this.id,
    required this.title,
    this.venue = '',
    this.year = 0,
    this.citedByCount = 0,
    required this.savedAt,
  });

  final String id;
  final String title;
  final String venue;
  final int year;
  final int citedByCount;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'venue': venue,
        'year': year,
        'cited_by_count': citedByCount,
        'saved_at': savedAt.toIso8601String(),
      };

  static SavedPaper? tryFromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) return null;
    return SavedPaper(
      id: id,
      title: (j['title'] ?? '') as String,
      venue: (j['venue'] ?? '') as String,
      year: (j['year'] ?? 0) as int,
      citedByCount: (j['cited_by_count'] ?? 0) as int,
      savedAt: DateTime.tryParse((j['saved_at'] ?? '') as String) ??
          DateTime.now(),
    );
  }
}

/// Reading list, newest-saved first. [prime] runs in main() before the first
/// build. When authenticated, operations sync in the background with Athena's API.
@riverpod
class SavedPapers extends _$SavedPapers {
  static const _key = 'athena.saved.papers';
  static List<SavedPaper> _cache = const [];

  @override
  List<SavedPaper> build() {
    // If authenticated, schedule a server sync
    if (UserPreferences.instance.authToken != null) {
      Future.microtask(() => syncWithServer());
    }
    return _cache;
  }

  static Future<void> prime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    _cache = raw
        .map((s) {
          try {
            return SavedPaper.tryFromJson(
                (jsonDecode(s) as Map).cast<String, dynamic>());
          } on FormatException {
            return null;
          }
        })
        .whereType<SavedPaper>()
        .toList();
  }

  bool isSaved(String paperId) => state.any((p) => p.id == paperId);

  void toggle(SavedPaper paper) {
    if (isSaved(paper.id)) {
      state = state.where((p) => p.id != paper.id).toList();
      _syncRemoteRemove(paper.id);
    } else {
      state = [paper, ...state];
      _syncRemoteAdd(paper.id);
    }
    _persist(state);
  }

  void remove(String paperId) {
    state = state.where((p) => p.id != paperId).toList();
    _syncRemoteRemove(paperId);
    _persist(state);
  }

  void _syncRemoteAdd(String paperId) {
    if (UserPreferences.instance.authToken != null) {
      ref.read(bookmarksRepositoryProvider).addBookmark(paperId).catchError((_) {});
    }
  }

  void _syncRemoteRemove(String paperId) {
    if (UserPreferences.instance.authToken != null) {
      ref.read(bookmarksRepositoryProvider).removeBookmark(paperId).catchError((_) {});
    }
  }

  Future<void> syncWithServer() async {
    if (UserPreferences.instance.authToken == null) return;
    try {
      final remote = await ref.read(bookmarksRepositoryProvider).listBookmarks();
      final currentMap = {for (final p in state) p.id: p};
      for (final r in remote) {
        if (!currentMap.containsKey(r.id)) {
          currentMap[r.id] = SavedPaper(
            id: r.id,
            title: r.title,
            venue: r.venueName,
            year: r.year,
            citedByCount: r.citedByCount,
            savedAt: DateTime.now(),
          );
        }
      }
      state = currentMap.values.toList();
      await _persist(state);
    } catch (_) {
      // Offline fallback: keep existing local cache
    }
  }

  Future<void> _persist(List<SavedPaper> papers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      papers.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
