import 'ai_models.dart';

abstract interface class AiRepository {
  /// Structured summary at the requested level; cached server-side by
  /// content hash, so repeats cost zero tokens.
  Future<PaperSummaryAI> summarize(String paperId, ExplanationLevel level);

  Future<String> createSession(String paperId);

  Future<List<ChatMessage>> messages(String sessionId);

  /// Streams one grounded assistant reply (SSE): deltas then a done event.
  Stream<ChatStreamEvent> ask(String sessionId, String content);
}
