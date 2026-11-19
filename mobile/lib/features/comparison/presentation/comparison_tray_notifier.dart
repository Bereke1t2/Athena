import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/user_preferences.dart';
import '../domain/comparison_tray_models.dart';

class ComparisonTrayNotifier extends StateNotifier<ComparisonTrayState> {
  ComparisonTrayNotifier({UserPreferences? prefs})
      : _prefs = prefs ?? UserPreferences.instance,
        super(const ComparisonTrayState()) {
    _restoreFromStorage();
  }

  final UserPreferences _prefs;

  void _restoreFromStorage() {
    try {
      final raw = _prefs.comparisonTrayJson;
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final items = decoded
            .map((e) => ComparisonTrayItem.fromJson(e as Map<String, dynamic>))
            .where((item) => item.paperId.isNotEmpty)
            .take(4)
            .toList();
        state = state.copyWith(items: items);
      }
    } catch (_) {
      // Ignore corrupted stored data
    }
  }

  Future<void> _persist() async {
    try {
      if (state.items.isEmpty) {
        await _prefs.clearComparisonTray();
      } else {
        final encoded = jsonEncode(state.items.map((e) => e.toJson()).toList());
        await _prefs.setComparisonTrayJson(encoded);
      }
    } catch (_) {
      // Graceful fallback for non-critical preference writes
    }
  }

  /// Adds a paper to the comparison tray.
  /// Returns `true` if added successfully, `false` if tray is full (4 papers)
  /// or already contains this paper.
  bool addPaper(ComparisonTrayItem item) {
    if (item.paperId.isEmpty) return false;
    if (state.containsPaper(item.paperId)) return false;
    if (state.isFull) return false;

    final updated = [...state.items, item];
    state = state.copyWith(items: updated);
    _persist();
    return true;
  }

  /// Removes a paper from the comparison tray.
  void removePaper(String paperId) {
    if (!state.containsPaper(paperId)) return;

    final updated = state.items.where((i) => i.paperId != paperId).toList();
    state = state.copyWith(
      items: updated,
      isExpanded: updated.isEmpty ? false : state.isExpanded,
    );
    _persist();
  }

  /// Toggles paper presence in tray. Returns `true` if paper is now in tray.
  bool togglePaper(ComparisonTrayItem item) {
    if (state.containsPaper(item.paperId)) {
      removePaper(item.paperId);
      return false;
    } else {
      return addPaper(item);
    }
  }

  /// Clears all papers from the comparison tray.
  void clear() {
    state = const ComparisonTrayState(items: [], isExpanded: false);
    _persist();
  }

  /// Toggles tray between docked compact pill and expanded view.
  void toggleExpanded() {
    state = state.copyWith(isExpanded: !state.isExpanded);
  }

  /// Explicitly sets expansion state.
  void setExpanded(bool expanded) {
    state = state.copyWith(isExpanded: expanded);
  }
}

final comparisonTrayProvider =
    StateNotifierProvider<ComparisonTrayNotifier, ComparisonTrayState>(
  (ref) => ComparisonTrayNotifier(),
);
