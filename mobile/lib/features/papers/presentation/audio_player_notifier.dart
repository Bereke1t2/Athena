import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_playback.dart';
import '../domain/paper.dart';

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlaybackState>(AudioPlayerNotifier.new);

class AudioPlayerNotifier extends Notifier<AudioPlaybackState> {
  Timer? _ticker;
  Timer? _sleepTimer;

  @override
  AudioPlaybackState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _sleepTimer?.cancel();
    });

    return const AudioPlaybackState(
      currentTrack: null,
      isPlaying: false,
      currentPosition: Duration.zero,
      speed: 1.0,
      recentTracks: [],
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isPlaying) return;
      final track = state.currentTrack;
      if (track == null) return;

      final stepSeconds = (1 * state.speed).round();
      final newPos = state.currentPosition + Duration(seconds: stepSeconds > 0 ? stepSeconds : 1);

      if (newPos >= track.totalDuration) {
        state = state.copyWith(
          isPlaying: false,
          currentPosition: track.totalDuration,
        );
        _ticker?.cancel();
      } else {
        state = state.copyWith(currentPosition: newPos);
      }
    });
  }

  void playTrack(AudioTrack track) {
    final recent = [track, ...state.recentTracks.where((t) => t.id != track.id)].take(5).toList();
    state = state.copyWith(
      currentTrack: track,
      isPlaying: true,
      currentPosition: Duration.zero,
      recentTracks: recent,
    );
    _startTicker();
  }

  void playPaper(PaperSummary paper, {String? abstractText, List<String> topics = const []}) {
    final track = AudioTrack.fromPaper(
      id: paper.id,
      title: paper.title,
      venue: paper.venueName.isNotEmpty ? paper.venueName : paper.publicationType,
      year: paper.year,
      abstractText: abstractText ?? paper.abstract,
      topics: topics,
    );
    playTrack(track);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void play() {
    state = state.copyWith(isPlaying: true);
    _startTicker();
  }

  void pause() {
    _ticker?.cancel();
    state = state.copyWith(isPlaying: false);
  }

  void seekTo(Duration position) {
    final track = state.currentTrack;
    if (track == null) return;
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(0, track.totalDuration.inMilliseconds),
    );
    state = state.copyWith(currentPosition: clamped);
  }

  void seekToProgress(double ratio) {
    final track = state.currentTrack;
    if (track == null) return;
    final ms = (track.totalDuration.inMilliseconds * ratio.clamp(0.0, 1.0)).round();
    seekTo(Duration(milliseconds: ms));
  }

  void skipSeconds(int seconds) {
    final newPos = state.currentPosition + Duration(seconds: seconds);
    seekTo(newPos);
  }

  void seekToChapter(int chapterIndex) {
    final track = state.currentTrack;
    if (track == null) return;
    final ch = track.chapters.firstWhere(
      (c) => c.index == chapterIndex,
      orElse: () => track.chapters.first,
    );
    seekTo(ch.startOffset);
  }

  void setSpeed(double speed) {
    state = state.copyWith(speed: speed);
  }

  void setSleepTimer(int? minutes) {
    _sleepTimer?.cancel();
    if (minutes == null || minutes <= 0) {
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    state = state.copyWith(sleepTimerMinutes: minutes);
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      pause();
      state = state.copyWith(clearSleepTimer: true);
    });
  }

  void addToQueue(AudioTrack track) {
    if (state.queue.any((t) => t.id == track.id)) return;
    state = state.copyWith(queue: [...state.queue, track]);
  }

  void stopAndDismiss() {
    _ticker?.cancel();
    _sleepTimer?.cancel();
    state = state.copyWith(
      isPlaying: false,
      clearCurrentTrack: true,
      currentPosition: Duration.zero,
      clearSleepTimer: true,
    );
  }
}
