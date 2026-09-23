import 'comparison_models.dart';

abstract class ComparisonRepository {
  Future<ComparisonReport> comparePapers(List<String> paperIds);
}
