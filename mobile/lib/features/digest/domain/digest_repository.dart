import '../../papers/domain/audio_playback.dart';
import 'digest_models.dart';

abstract class DigestRepository {
  Future<UserDigest> getLatestDigest({List<String>? topics});
  Future<UserDigest> generateDigest({String frequency = 'weekly', List<String>? topics});
  Future<AudioTrack> synthesizeDigestAudio({String? voice, List<String>? topics});
}
