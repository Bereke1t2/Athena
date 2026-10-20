import 'package:athena/core/di.dart';
import 'package:athena/features/digest/domain/digest_models.dart';
import 'package:athena/features/digest/domain/digest_repository.dart';
import 'package:athena/features/digest/presentation/digest_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDigestRepository implements DigestRepository {
  UserDigest? digest;

  @override
  Future<UserDigest> getLatestDigest() async {
    return digest ??
        UserDigest(
          id: 'd1',
          generatedAt: DateTime.utc(2026, 10, 20),
          frequency: 'weekly',
          pulses: const [
            TopicPulse(
              topicSlug: 'ai',
              topicName: 'Artificial Intelligence',
              paperCount: 12,
              velocity: 2.5,
              keyThemes: ['LLM', 'Agents'],
            ),
          ],
          sections: const [],
          topTakeaways: const ['Key finding 1'],
        );
  }

  @override
  Future<UserDigest> generateDigest({String frequency = 'weekly'}) async {
    final fresh = UserDigest(
      id: 'd2',
      generatedAt: DateTime.utc(2026, 10, 20),
      frequency: frequency,
      pulses: const [],
      sections: const [],
      topTakeaways: const ['Fresh finding'],
    );
    digest = fresh;
    return fresh;
  }
}

void main() {
  test('digest notifier loads latest briefing and regenerates', () async {
    final fake = FakeDigestRepository();
    final container = ProviderContainer(
      overrides: [
        digestRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(digestNotifierProvider.notifier);
    await notifier.loadLatest();
    final state = container.read(digestNotifierProvider);

    expect(state.isLoading, isFalse);
    expect(state.digest, isNotNull);
    expect(state.digest!.id, 'd1');
    expect(state.digest!.pulses.length, 1);
    expect(state.digest!.pulses.first.topicSlug, 'ai');

    // Regenerate
    await notifier.regenerate();
    final updated = container.read(digestNotifierProvider);
    expect(updated.digest!.id, 'd2');
    expect(updated.digest!.topTakeaways.first, 'Fresh finding');
  });
}
