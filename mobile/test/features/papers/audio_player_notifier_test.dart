import 'dart:async';

import 'package:athena/features/papers/data/audio_player_service.dart';
import 'package:athena/features/papers/domain/audio_playback.dart';
import 'package:athena/features/papers/presentation/audio_player_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class FakeAudioPlayerService implements AudioPlayerService {
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

  void emitPosition(Duration pos) {
    currentPos = pos;
    _positionController.add(pos);
  }

  void emitDuration(Duration dur) {
    totalDur = dur;
    _durationController.add(dur);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPlayerService fakeService;
  late ProviderContainer container;

  setUp(() {
    fakeService = FakeAudioPlayerService();
    container = ProviderContainer(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(fakeService),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  const testTrack = AudioTrack(
    id: 'test-track-1',
    paperId: 'paper-123',
    title: 'Attention Is All You Need',
    authorVenue: 'NeurIPS · 2017',
    totalDuration: Duration(minutes: 10),
    chapters: [
      AudioChapter(
        index: 1,
        title: 'Introduction',
        startOffset: Duration.zero,
        duration: Duration(minutes: 3),
      ),
      AudioChapter(
        index: 2,
        title: 'Self-Attention Mechanism',
        startOffset: Duration(minutes: 3),
        duration: Duration(minutes: 4),
      ),
      AudioChapter(
        index: 3,
        title: 'Empirical Results',
        startOffset: Duration(minutes: 7),
        duration: Duration(minutes: 3),
      ),
    ],
  );

  test('audio player starts with clean idle state', () {
    final state = container.read(audioPlayerProvider);
    expect(state.currentTrack, isNull);
    expect(state.isPlaying, isFalse);
    expect(state.currentPosition, Duration.zero);
    expect(state.recentTracks, isEmpty);
  });

  test('playTrack loads audio stream URL and starts playback', () async {
    final notifier = container.read(audioPlayerProvider.notifier);
    await notifier.playTrack(testTrack);

    final state = container.read(audioPlayerProvider);
    expect(state.currentTrack?.id, 'test-track-1');
    expect(state.isPlaying, isTrue);
    expect(state.recentTracks, contains(testTrack));
    expect(fakeService.lastLoadedUrl, contains('/research/papers/paper-123/audio/stream'));
  });

  test('togglePlayPause toggles playback state', () async {
    final notifier = container.read(audioPlayerProvider.notifier);
    await notifier.playTrack(testTrack);
    expect(container.read(audioPlayerProvider).isPlaying, isTrue);

    notifier.togglePlayPause();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(audioPlayerProvider).isPlaying, isFalse);

    notifier.togglePlayPause();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(container.read(audioPlayerProvider).isPlaying, isTrue);
  });

  test('seekTo and seekToChapter navigate track positions', () async {
    final notifier = container.read(audioPlayerProvider.notifier);
    await notifier.playTrack(testTrack);

    await notifier.seekTo(const Duration(minutes: 2));
    expect(container.read(audioPlayerProvider).currentPosition, const Duration(minutes: 2));

    notifier.seekToChapter(2);
    expect(container.read(audioPlayerProvider).currentPosition, const Duration(minutes: 3));
    expect(container.read(audioPlayerProvider).currentChapterIndex, 2);
  });

  test('setSpeed updates playback rate in state and hardware service', () async {
    final notifier = container.read(audioPlayerProvider.notifier);
    await notifier.setSpeed(1.5);

    expect(container.read(audioPlayerProvider).speed, 1.5);
    expect(fakeService.playbackSpeed, 1.5);
  });

  test('stopAndDismiss stops hardware service and resets current track', () async {
    final notifier = container.read(audioPlayerProvider.notifier);
    await notifier.playTrack(testTrack);
    await notifier.stopAndDismiss();

    final state = container.read(audioPlayerProvider);
    expect(state.currentTrack, isNull);
    expect(state.isPlaying, isFalse);
    expect(state.currentPosition, Duration.zero);
  });

  test('hardware positionStream updates state.currentPosition in real time', () async {
    final notifier = container.read(audioPlayerProvider.notifier);
    await notifier.playTrack(testTrack);

    fakeService.emitPosition(const Duration(seconds: 45));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(container.read(audioPlayerProvider).currentPosition, const Duration(seconds: 45));
  });
}
