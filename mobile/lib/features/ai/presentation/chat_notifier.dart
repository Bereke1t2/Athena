import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di.dart';
import '../domain/ai_models.dart';

part 'chat_notifier.freezed.dart';
part 'chat_notifier.g.dart';

@freezed
sealed class ChatThreadState with _$ChatThreadState {
  const factory ChatThreadState({
    String? sessionId,
    @Default(<ChatMessage>[]) List<ChatMessage> messages,

    /// Text currently streaming in (not yet finalized as a message).
    @Default('') String streaming,
    @Default(false) bool sending,
  }) = _ChatThreadState;
}

/// One chat thread per paper. The session is created lazily on first send.
/// [keepAlive] preserves the transcript while navigating between screens.
@riverpod
class ChatThread extends _$ChatThread {
  @override
  ChatThreadState build(String paperId) => const ChatThreadState();

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.sending) return;
    final repo = ref.read(aiRepositoryProvider);

    var sessionId = state.sessionId;
    try {
      sessionId ??= await repo.createSession(paperId);
    } catch (e) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'local-err-${DateTime.now()}',
            role: 'assistant',
            content: 'Failed to start chat: ${e.toString()}',
          ),
        ],
      );
      return;
    }

    final userMsg = ChatMessage(id: 'local-${DateTime.now()}', role: 'user', content: content);
    state = state.copyWith(
      sessionId: sessionId,
      messages: [...state.messages, userMsg],
      sending: true,
      streaming: '',
    );

    final buffer = StringBuffer();
    try {
      await for (final event in repo.ask(sessionId, content)) {
        switch (event) {
          case ChatDelta(:final text):
            buffer.write(text);
            state = state.copyWith(streaming: buffer.toString());
          case ChatDone(:final message):
            final finalContent = message.content.isNotEmpty ? message.content : buffer.toString().trim();
            state = state.copyWith(
              messages: [...state.messages, message.copyWith(content: finalContent)],
              streaming: '',
              sending: false,
            );
          case ChatFailed(:final message):
            state = state.copyWith(
              messages: [
                ...state.messages,
                ChatMessage(
                  id: 'local-err-${DateTime.now()}',
                  role: 'assistant',
                  content: message,
                ),
              ],
              streaming: '',
              sending: false,
            );
        }
      }
    } catch (e) {
      final partial = buffer.toString().trim();
      state = state.copyWith(
        messages: [
          ...state.messages,
          if (partial.isNotEmpty)
            ChatMessage(id: 'local-partial', role: 'assistant', content: partial),
          if (partial.isEmpty)
            ChatMessage(
              id: 'local-err-${DateTime.now()}',
              role: 'assistant',
              content: 'Connection error: ${e.toString()}',
            ),
        ],
        streaming: '',
        sending: false,
      );
      return;
    }
    // Stream ended without a done frame.
    if (state.sending) {
      final partial = buffer.toString().trim();
      state = state.copyWith(
        messages: [
          ...state.messages,
          if (partial.isNotEmpty)
            ChatMessage(id: 'local-partial', role: 'assistant', content: partial),
        ],
        streaming: '',
        sending: false,
      );
    }
  }
}
