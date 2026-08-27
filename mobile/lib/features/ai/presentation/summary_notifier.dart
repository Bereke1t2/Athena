import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di.dart';
import '../domain/ai_models.dart';

part 'summary_notifier.freezed.dart';
part 'summary_notifier.g.dart';

@freezed
sealed class SummaryState with _$SummaryState {
  const factory SummaryState({
    @Default(ExplanationLevel.intermediate) ExplanationLevel level,
    @Default(AsyncValue<PaperSummaryAI>.loading())
    AsyncValue<PaperSummaryAI> data,
  }) = _SummaryState;
}

/// One summary per paper; switching levels re-fetches (server cache makes
/// repeat levels free).
@riverpod
class SummaryNotifier extends _$SummaryNotifier {
  bool _disposed = false;

  @override
  SummaryState build(String paperId) {
    ref.onDispose(() => _disposed = true);
    return const SummaryState();
  }

  Future<void> load([ExplanationLevel? level]) async {
    final target = level ?? state.level;
    state = state.copyWith(level: target, data: const AsyncValue.loading());
    try {
      final summary = await ref.read(aiRepositoryProvider).summarize(paperId, target);
      if (_disposed) return;
      state = state.copyWith(data: AsyncValue.data(summary));
    } catch (e, st) {
      if (_disposed) return;
      state = state.copyWith(data: AsyncValue.error(e, st));
    }
  }
}
