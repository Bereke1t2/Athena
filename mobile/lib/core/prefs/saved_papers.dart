import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'saved_papers.g.dart';

/// A minimal saved-paper record persisted locally (no auth yet — Phase 5 will
/// move these server-side).
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

/// Local reading list, newest-saved first. [prime] must run in main() before
/// the first widget build so the synchronous provider starts populated.
@riverpod
class SavedPapers extends _$SavedPapers {
  static const _key = 'athena.saved.papers';
  static List<SavedPaper> _cache = const [];

  @override
  List<SavedPaper> build() => _cache;

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
    } else {
      state = [paper, ...state];
    }
    _persist(state);
  }

  void remove(String paperId) {
    state = state.where((p) => p.id != paperId).toList();
    _persist(state);
  }

  Future<void> _persist(List<SavedPaper> papers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      papers.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
