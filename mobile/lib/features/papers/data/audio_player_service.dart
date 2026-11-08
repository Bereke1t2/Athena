import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

abstract class AudioPlayerService {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<ProcessingState> get processingStateStream;
  Duration get position;
  Duration? get duration;
  bool get isPlaying;

  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPlayerService implements AudioPlayerService {
  JustAudioPlayerService([AudioPlayer? player]) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<ProcessingState> get processingStateStream => _player.processingStateStream;

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  bool get isPlaying => _player.playing;

  @override
  Future<void> setUrl(String url) async {
    try {
      await _player.setUrl(url);
    } catch (e) {
      debugPrint('JustAudioPlayerService.setUrl error: $e');
      rethrow;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = JustAudioPlayerService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
