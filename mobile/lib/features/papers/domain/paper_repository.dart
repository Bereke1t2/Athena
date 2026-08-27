import 'paper.dart';

/// Repository interface lives in feature domain/ (conventions rule 4).
abstract interface class PaperRepository {
  Future<PaperDetail> getById(String id);
}
