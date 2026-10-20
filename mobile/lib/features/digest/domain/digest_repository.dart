import 'digest_models.dart';

abstract class DigestRepository {
  Future<UserDigest> getLatestDigest();
  Future<UserDigest> generateDigest({String frequency = 'weekly'});
}
