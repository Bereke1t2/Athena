import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../data/audio_player_service.dart';

import '../domain/audio_playback.dart';
import '../domain/paper.dart';

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlaybackState>(AudioPlayerNotifier.new);

class AudioPlayerNotifier extends Notifier<AudioPlaybackState> {
  Timer? _ticker;
  Timer? _sleepTimer;
  AudioPlayerService? _playerService;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<bool>? _playingSub;

  @override
  AudioPlaybackState build() {
    _playerService = ref.watch(audioPlayerServiceProvider);

    _posSub?.cancel();
    _durSub?.cancel();
    _playingSub?.cancel();

    _posSub = _playerService?.positionStream.listen((pos) {
      if (state.currentTrack != null) {
        state = state.copyWith(currentPosition: pos);
      }
    });

    _durSub = _playerService?.durationStream.listen((dur) {
      if (dur != null && dur > Duration.zero && state.currentTrack != null) {
        if (state.currentTrack!.totalDuration != dur) {
          state = state.copyWith(
            currentTrack: state.currentTrack!.copyWith(totalDuration: dur),
          );
        }
      }
    });

    _playingSub = _playerService?.playingStream.listen((playing) {
      if (state.isPlaying != playing) {
        state = state.copyWith(isPlaying: playing);
        if (playing) {
          _startTicker();
        } else {
          _ticker?.cancel();
        }
      }
    });
    ref.onDispose(() {
      _ticker?.cancel();
      _sleepTimer?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _playingSub?.cancel();
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

  Future<void> playTrack(AudioTrack track) async {
    final recent = [track, ...state.recentTracks.where((t) => t.id != track.id)].take(5).toList();
    state = state.copyWith(
      currentTrack: track,
      isPlaying: true,
      currentPosition: Duration.zero,
      recentTracks: recent,
    );

    final streamUrl = _resolveAudioUrl(track);
    bool streamStarted = false;
    if (streamUrl.isNotEmpty && _playerService != null) {
      try {
        await _playerService!.setUrl(streamUrl);
        await _playerService!.setSpeed(state.speed);
        await _playerService!.play();
        streamStarted = true;
      } catch (e) {
        debugPrint('AudioPlayerNotifier: hardware streaming failed, falling back to simulated playback: $e');
      }
    }

    if (!streamStarted) {
      _startTicker();
    }
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
