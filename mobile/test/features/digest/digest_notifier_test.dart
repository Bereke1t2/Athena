import 'package:athena/core/di.dart';
import 'package:athena/core/error/failure.dart';
import 'package:athena/features/digest/data/digest_repository_impl.dart';
import 'package:athena/features/digest/domain/digest_models.dart';
import 'package:athena/features/digest/domain/digest_repository.dart';
import 'package:athena/features/digest/presentation/digest_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDigestRepository implements DigestRepository {
  UserDigest? digest;
  bool shouldThrow = false;

  @override
  Future<UserDigest> getLatestDigest() async {
    if (shouldThrow) {
      throw const Failure.server(statusCode: 500, message: 'Server error');
    }
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
    if (shouldThrow) {
      throw const Failure.server(statusCode: 500, message: 'Server error');
    }
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
  group('DigestNotifier', () {
    test('loads latest briefing and regenerates', () async {
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

    test('captures repository failures into state.error as Failure', () async {
      final fake = FakeDigestRepository()..shouldThrow = true;
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
      expect(state.error, isA<ServerFailure>());
    });
  });

  group('DigestRepositoryImpl', () {
    test('parses standard snake_case wire DTO payload', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'id': 'digest-123',
              'user_id': 'user-456',
              'generated_at': '2026-11-01T12:00:00Z',
              'frequency': 'weekly',
              'pulses': [
                {
                  'topic_slug': 'ai',
                  'topic_name': 'Artificial Intelligence',
                  'paper_count': 5,
                  'velocity': 1.5,
                  'key_themes': ['Deep Learning', 'Transformers']
                }
              ],
              'sections': [
                {
                  'title': 'Breakthroughs',
                  'description': 'Top papers this week',
                  'papers': [
                    {
                      'id': '00000000-0000-0000-0000-000000000001',
                      'title': 'Attention Is All You Need',
                      'abstract': 'The Transformer model...',
                      'publication_date': '2017-06-12T00:00:00Z',
                      'publication_year': 2017,
                      'venue': {'name': 'NeurIPS'},
                      'publication_type': 'conference_paper',
                      'oa_status': 'gold',
                      'is_open_access': true,
                      'cited_by_count': 50000
                    }
                  ]
                }
              ],
              'top_takeaways': ['Major efficiency leaps']
            },
          ));
        },
      ));

      final repo = DigestRepositoryImpl(dio);
      final digest = await repo.getLatestDigest();

      expect(digest.id, 'digest-123');
      expect(digest.sections.length, 1);
      expect(digest.sections.first.papers.length, 1);
      final paper = digest.sections.first.papers.first;
      expect(paper.title, 'Attention Is All You Need');
      expect(paper.year, 2017);
      expect(paper.venueName, 'NeurIPS');
      expect(paper.isOpenAccess, isTrue);
      expect(paper.citedByCount, 50000);
    });

    test('defensively normalizes PascalCase and flat legacy keys', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'id': 'legacy-digest-1',
              'generated_at': '2026-11-01T12:00:00Z',
              'frequency': 'weekly',
              'pulses': [],
              'sections': [
                {
                  'title': 'Legacy Section',
                  'description': 'Unnormalized keys',
                  'papers': [
                    {
                      'ID': '00000000-0000-0000-0000-000000000002',
                      'Title': 'Legacy Paper Title',
                      'Abstract': 'Some abstract text',
                      'Year': 2021,
                      'VenueName': 'Nature',
                      'PublicationType': 'article',
                      'OAStatus': 'green',
                      'IsOpenAccess': true,
                      'CitedByCount': 1200
                    }
                  ]
                }
              ],
              'top_takeaways': ['Finding 1']
            },
          ));
        },
      ));

      final repo = DigestRepositoryImpl(dio);
      final digest = await repo.getLatestDigest();

      expect(digest.id, 'legacy-digest-1');
      expect(digest.sections.first.papers.length, 1);
      final paper = digest.sections.first.papers.first;
      expect(paper.id, '00000000-0000-0000-0000-000000000002');
      expect(paper.title, 'Legacy Paper Title');
      expect(paper.year, 2021);
      expect(paper.venueName, 'Nature');
      expect(paper.isOpenAccess, isTrue);
      expect(paper.citedByCount, 1200);
    });

    test('wraps dio 401 response into Failure', () async {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: {
                'error': {'code': 'unauthorized', 'message': 'authentication required'}
              },
            ),
            type: DioExceptionType.badResponse,
          ));
        },
      ));

      final repo = DigestRepositoryImpl(dio);
      expect(() => repo.getLatestDigest(), throwsA(isA<ServerFailure>()));
    });
  });
}
