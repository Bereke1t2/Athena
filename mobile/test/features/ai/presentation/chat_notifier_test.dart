import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/ai/domain/ai_models.dart';
import 'package:athena/features/ai/domain/ai_repository.dart';
import 'package:athena/features/ai/presentation/chat_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAiRepository implements AiRepository {
  List<ChatMessage> mockMessages = [];
  String nextSessionId = 'sess-new-1';

  @override
  Future<String> createSession(String paperId) async {
    return nextSessionId;
  }

  @override
  Future<List<ChatMessage>> messages(String sessionId) async {
    return mockMessages;
  }

  @override
  Stream<ChatStreamEvent> ask(String sessionId, String content) async* {
    yield const ChatDelta('Test ');
    yield const ChatDelta('answer');
    yield const ChatDone(
      ChatMessage(
        id: 'msg-resp',
        role: 'assistant',
        content: 'Test answer',
      ),
    );
  }

  @override
  Future<PaperSummaryAI> summarize(String paperId, ExplanationLevel level) async {
    throw UnimplementedError();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiRepository fakeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load();
    fakeRepo = FakeAiRepository();
  });

  test('chat thread initializes empty when no saved session exists', () {
    final container = ProviderContainer(
      overrides: [aiRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    final state = container.read(chatThreadProvider('paper-1'));
    expect(state.sessionId, isNull);
    expect(state.messages, isEmpty);
  });

  test('chat thread restores saved sessionId and fetches messages from repository', () async {
    fakeRepo.mockMessages = [
      const ChatMessage(
        id: 'm1',
        role: 'user',
        content: 'What is the methodology?',
      ),
      const ChatMessage(
        id: 'm2',
        role: 'assistant',
        content: 'The authors used an empirical trial.',
      ),
    ];

    await UserPreferences.instance.setChatSessionId('paper-1', 'sess-persisted-99');

    final container = ProviderContainer(
      overrides: [aiRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(chatThreadProvider('paper-1'), (_, __) {});
    addTearDown(sub.close);

    final initial = container.read(chatThreadProvider('paper-1'));
    expect(initial.sessionId, 'sess-persisted-99');

    // Allow Future.microtask and messages fetch to complete
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final updated = container.read(chatThreadProvider('paper-1'));
    expect(updated.messages.length, 2);
    expect(updated.messages.first.content, 'What is the methodology?');
    expect(updated.messages.last.content, 'The authors used an empirical trial.');
  });

  test('sending a prompt creates a session and persists it in UserPreferences', () async {
    final container = ProviderContainer(
      overrides: [aiRepositoryProvider.overrideWithValue(fakeRepo)],
    );
    addTearDown(container.dispose);

    final sub = container.listen(chatThreadProvider('paper-2'), (_, __) {});
    addTearDown(sub.close);

    expect(UserPreferences.instance.getChatSessionId('paper-2'), isNull);

    await container.read(chatThreadProvider('paper-2').notifier).send('Explain results');

    final state = container.read(chatThreadProvider('paper-2'));
    expect(state.sessionId, 'sess-new-1');
    expect(state.messages.length, 2);
    expect(state.messages.first.role, 'user');
    expect(state.messages.last.content, 'Test answer');
    expect(UserPreferences.instance.getChatSessionId('paper-2'), 'sess-new-1');
  });
}
