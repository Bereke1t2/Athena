import 'dart:async';

import 'package:athena/core/di.dart';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/digest/domain/digest_models.dart';
import 'package:athena/features/digest/domain/digest_repository.dart';
import 'package:athena/features/digest/presentation/widgets/digest_podcast_card.dart';
import 'package:athena/features/papers/data/audio_player_service.dart';
import 'package:athena/features/papers/domain/audio_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAudioPlayerService implements AudioPlayerService {
  final _posCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playingCtrl = StreamController<bool>.broadcast();
  final _stateCtrl = StreamController<ProcessingState>.broadcast();

  String? loadedUrl;
  Duration pos = Duration.zero;
  bool playing = false;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;
  @override
  Stream<bool> get playingStream => _playingCtrl.stream;
  @override
  Stream<ProcessingState> get processingStateStream => _stateCtrl.stream;
  @override
  Duration get position => pos;
  @override
  Duration? get duration => const Duration(minutes: 8);
  @override
  bool get isPlaying => playing;

  @override
  Future<void> setUrl(String url) async {
    loadedUrl = url;
  }

  @override
  Future<void> play() async {
    playing = true;
    _playingCtrl.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    pos = position;
    _posCtrl.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> stop() async {
    playing = false;
    _playingCtrl.add(false);
  }

  @override
  Future<void> dispose() async {
    await _posCtrl.close();
    await _durCtrl.close();
    await _playingCtrl.close();
    await _stateCtrl.close();
  }
}

class _FakeDigestRepository implements DigestRepository {
  @override
  Future<UserDigest> getLatestDigest({List<String>? topics}) async {
    return UserDigest(
      id: 'digest-1',
      generatedAt: DateTime.utc(2026, 11, 19),
      frequency: 'weekly',
      aiSummary: 'Weekly synthesis of foundational models and quantum compute.',
      pulses: const [],
      sections: const [],
      topTakeaways: const ['Takeaway 1'],
    );
  }

  @override
  Future<UserDigest> generateDigest({String frequency = 'weekly', List<String>? topics}) async =>
      throw UnimplementedError();

  @override
  Future<AudioTrack> synthesizeDigestAudio({String? voice, List<String>? topics}) async {
    return const AudioTrack(
      id: 'podcast-101',
      title: 'The Week in Science: Multidisciplinary Insights',
      authorVenue: 'Athena AI Synthesis',
      totalDuration: Duration(minutes: 8),
      audioUrl: '/api/v1/research/digest/audio/stream',
      chapters: [
        AudioChapter(
          index: 1,
          title: '01 Executive Summary & Scientific Pulse',
          startOffset: Duration.zero,
          duration: Duration(minutes: 2),
        ),
        AudioChapter(
          index: 2,
          title: '02 Highlights in Artificial Intelligence',
          startOffset: Duration(minutes: 2),
          duration: Duration(minutes: 3),
        ),
        AudioChapter(
          index: 3,
          title: '03 Top Takeaways & Outlook',
          startOffset: Duration(minutes: 5),
          duration: Duration(minutes: 3),
        ),
      ],
      takeaways: ['Takeaway 1'],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load(force: true);
  });

  Widget createTestApp({
    required DigestRepository repo,
    required AudioPlayerService audioService,
  }) {
    return ProviderScope(
      overrides: [
        digestRepositoryProvider.overrideWithValue(repo),
        audioPlayerServiceProvider.overrideWithValue(audioService),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DigestPodcastCard(),
          ),
        ),
      ),
    );
  }

  group('DigestPodcastCard', () {
    testWidgets('renders podcast badge, title, duration pill, and voice button',
        (tester) async {
      final fakeRepo = _FakeDigestRepository();
      final fakeAudio = _FakeAudioPlayerService();

      await tester.pumpWidget(createTestApp(repo: fakeRepo, audioService: fakeAudio));
      await tester.pumpAndSettle();

      expect(find.text('ATHENA PODCAST · WEEKLY BRIEFING'), findsOneWidget);
      expect(find.text('The Week in Science: Multidisciplinary Insights'), findsOneWidget);
      expect(find.text('8 MIN EPISODE'), findsOneWidget);
      expect(find.text('Synthesize & Listen'), findsOneWidget);
      expect(find.text('Alloy'), findsOneWidget);
    });

    testWidgets('synthesizes audio briefing and loads into player',
        (tester) async {
      final fakeRepo = _FakeDigestRepository();
      final fakeAudio = _FakeAudioPlayerService();

      await tester.pumpWidget(createTestApp(repo: fakeRepo, audioService: fakeAudio));
      await tester.pumpAndSettle();

      // Tap Synthesize & Listen
      await tester.tap(find.text('Synthesize & Listen'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Now audio track is loaded and synthesized
      expect(find.text('Pause Briefing'), findsOneWidget);
      expect(find.text('3 CHAPTERS · TIMELINE'), findsOneWidget);

      // Expand chapters
      await tester.tap(find.text('3 CHAPTERS · TIMELINE'));
      await tester.pumpAndSettle();

      expect(find.text('01 Executive Summary & Scientific Pulse'), findsOneWidget);
      expect(find.text('02 Highlights in Artificial Intelligence'), findsOneWidget);
      expect(find.text('03 Top Takeaways & Outlook'), findsOneWidget);

      // Tap second chapter to seek
      await tester.tap(find.text('02 Highlights in Artificial Intelligence'));
      await tester.pumpAndSettle();

      expect(fakeAudio.pos, const Duration(minutes: 2));
    });

    testWidgets('allows changing selected voice via popup menu',
        (tester) async {
      final fakeRepo = _FakeDigestRepository();
      final fakeAudio = _FakeAudioPlayerService();

      await tester.pumpWidget(createTestApp(repo: fakeRepo, audioService: fakeAudio));
      await tester.pumpAndSettle();

      // Tap voice selector
      await tester.tap(find.text('Alloy'));
      await tester.pumpAndSettle();

      // Select 'Nova'
      await tester.tap(find.text('Nova').last);
      await tester.pumpAndSettle();

      expect(find.text('Nova'), findsOneWidget);
    });
  });
}
