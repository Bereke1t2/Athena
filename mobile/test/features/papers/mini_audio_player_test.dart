import 'dart:async';

import 'package:athena/features/papers/data/audio_player_service.dart';
import 'package:athena/features/papers/domain/audio_playback.dart';
import 'package:athena/features/papers/presentation/audio_player_notifier.dart';
import 'package:athena/features/papers/presentation/widgets/mini_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

class _FakePlayerService implements AudioPlayerService {
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _stateController = StreamController<ProcessingState>.broadcast();

  String? lastLoadedUrl;
  Duration currentPos = Duration.zero;
  Duration? totalDur;
  bool playing = false;
  double playbackSpeed = 1.0;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Stream<bool> get playingStream => _playingController.stream;

  @override
  Stream<ProcessingState> get processingStateStream => _stateController.stream;

  @override
  Duration get position => currentPos;

  @override
  Duration? get duration => totalDur;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> setUrl(String url) async {
    lastLoadedUrl = url;
  }

  @override
  Future<void> play() async {
    playing = true;
    _playingController.add(true);
  }

  @override
  Future<void> pause() async {
    playing = false;
    _playingController.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    currentPos = position;
    _positionController.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    playbackSpeed = speed;
  }

  @override
  Future<void> stop() async {
    playing = false;
    currentPos = Duration.zero;
    _playingController.add(false);
    _positionController.add(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
    await _stateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrack = AudioTrack(
    id: 'track-mini-1',
    paperId: 'paper-456',
    title: 'Attention Is All You Need',
    authorVenue: 'NeurIPS 2017',
    totalDuration: Duration(minutes: 10),
    chapters: [
      AudioChapter(
        index: 1,
        title: 'Introduction',
        startOffset: Duration.zero,
        duration: Duration(minutes: 4),
      ),
      AudioChapter(
        index: 2,
        title: 'Model Architecture',
        startOffset: Duration(minutes: 4),
        duration: Duration(minutes: 6),
      ),
    ],
  );

  Widget buildTestableWidget({
    required _FakePlayerService fakeService,
    required AudioPlayerNotifier notifier,
    GoRouter? customRouter,
  }) {
    if (customRouter != null) {
      return ProviderScope(
        overrides: [
          audioPlayerServiceProvider.overrideWithValue(fakeService),
          audioPlayerProvider.overrideWith(() => notifier),
        ],
        child: MaterialApp.router(
          routerConfig: customRouter,
        ),
      );
    }

    return ProviderScope(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(fakeService),
        audioPlayerProvider.overrideWith(() => notifier),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Main Screen')),
          bottomNavigationBar: MiniAudioPlayer(),
        ),
      ),
    );
  }

  group('MiniAudioPlayer', () {
    testWidgets('renders SizedBox.shrink when no track is loaded', (tester) async {
      final fakeService = _FakePlayerService();
      final notifier = AudioPlayerNotifier();

      await tester.pumpWidget(
        buildTestableWidget(fakeService: fakeService, notifier: notifier),
      );

      expect(find.byKey(const Key('mini_audio_player')), findsNothing);
      expect(find.text('Attention Is All You Need'), findsNothing);
    });

    testWidgets('renders track title, venue, and chapters when playing', (tester) async {
      final fakeService = _FakePlayerService();
      final notifier = AudioPlayerNotifier();

      await tester.pumpWidget(
        buildTestableWidget(fakeService: fakeService, notifier: notifier),
      );

      // Play track
      await notifier.playTrack(testTrack);
      await tester.pump();

      expect(find.byKey(const Key('mini_audio_player')), findsOneWidget);
      expect(find.text('Attention Is All You Need'), findsOneWidget);
      expect(find.textContaining('NeurIPS 2017 · Ch. 1'), findsOneWidget);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    });

    testWidgets('play/pause button toggles audio state', (tester) async {
      final fakeService = _FakePlayerService();
      final notifier = AudioPlayerNotifier();

      await tester.pumpWidget(
        buildTestableWidget(fakeService: fakeService, notifier: notifier),
      );

      await notifier.playTrack(testTrack);
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap pause
      await tester.tap(find.byKey(const Key('mini_audio_player_play_pause')));
      await tester.pump();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(notifier.state.isPlaying, isFalse);

      // Tap play
      await tester.tap(find.byKey(const Key('mini_audio_player_play_pause')));
      await tester.pump();

      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(notifier.state.isPlaying, isTrue);
    });

    testWidgets('skip 10 seconds button advances track position', (tester) async {
      final fakeService = _FakePlayerService();
      final notifier = AudioPlayerNotifier();

      await tester.pumpWidget(
        buildTestableWidget(fakeService: fakeService, notifier: notifier),
      );

      await notifier.playTrack(testTrack);
      await tester.pump();
      expect(notifier.state.currentPosition, Duration.zero);

      await tester.tap(find.byKey(const Key('mini_audio_player_skip_10')));
      await tester.pump();

      expect(notifier.state.currentPosition, const Duration(seconds: 10));
    });

    testWidgets('dismiss button calls stopAndDismiss and hides mini player', (tester) async {
      final fakeService = _FakePlayerService();
      final notifier = AudioPlayerNotifier();

      await tester.pumpWidget(
        buildTestableWidget(fakeService: fakeService, notifier: notifier),
      );

      await notifier.playTrack(testTrack);
      await tester.pump();
      expect(find.byKey(const Key('mini_audio_player')), findsOneWidget);

      await tester.tap(find.byKey(const Key('mini_audio_player_dismiss')));
      await tester.pump();

      expect(find.byKey(const Key('mini_audio_player')), findsNothing);
      expect(notifier.state.currentTrack, isNull);
      expect(notifier.state.isPlaying, isFalse);
    });

    testWidgets('tapping mini player navigates to /player route', (tester) async {
      final fakeService = _FakePlayerService();
      final notifier = AudioPlayerNotifier();

      var navigatedToPlayer = false;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Home Screen'),
              bottomNavigationBar: MiniAudioPlayer(),
            ),
          ),
          GoRoute(
            path: '/player',
            builder: (context, state) {
              navigatedToPlayer = true;
              return const Scaffold(body: Text('Now Playing Full Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestableWidget(
          fakeService: fakeService,
          notifier: notifier,
          customRouter: router,
        ),
      );

      await notifier.playTrack(testTrack);
      await tester.pump();

      // Tap on the tap area (artwork + titles)
      await tester.tap(find.byKey(const Key('mini_audio_player_tap_area')));
      await tester.pumpAndSettle();

      expect(navigatedToPlayer, isTrue);
      expect(find.text('Now Playing Full Screen'), findsOneWidget);
    });
  });
}
