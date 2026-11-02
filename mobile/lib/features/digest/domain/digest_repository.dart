import 'digest_models.dart';

abstract class DigestRepository {
  Future<UserDigest> getLatestDigest({List<String>? topics});
  Future<UserDigest> generateDigest({String frequency = 'weekly', List<String>? topics});
}
