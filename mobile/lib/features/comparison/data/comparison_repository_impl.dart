import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/comparison_models.dart';
import '../domain/comparison_repository.dart';

class ComparisonRepositoryImpl implements ComparisonRepository {
  ComparisonRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<ComparisonReport> comparePapers(List<String> paperIds) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/research/compare',
        data: {'paper_ids': paperIds},
      );
      final data = res.data!;
      final papersRaw = data['papers'] as List<dynamic>? ?? [];

      final papers = papersRaw.map((raw) {
        final d = raw as Map<String, dynamic>;
        final authorsRaw = d['authors'] as List<dynamic>? ?? [];
        final strengthsRaw = d['strengths'] as List<dynamic>? ?? [];
        final limitationsRaw = d['limitations'] as List<dynamic>? ?? [];

        return ComparisonMatrixItem(
          paperId: d['paper_id'] as String? ?? '',
          title: d['title'] as String? ?? '',
          authors: authorsRaw.map((a) => a.toString()).toList(),
          year: d['year'] as int? ?? 0,
          venue: d['venue'] as String? ?? '',
          keyTakeaway: d['key_takeaway'] as String? ?? '',
          methodology: d['methodology'] as String? ?? '',
          strengths: strengthsRaw.map((s) => s.toString()).toList(),
          limitations: limitationsRaw.map((l) => l.toString()).toList(),
        );
      }).toList();

      final consensusRaw = data['consensus_points'] as List<dynamic>? ?? [];
      final divergenceRaw = data['divergence_points'] as List<dynamic>? ?? [];

      return ComparisonReport(
        papers: papers,
        consensusPoints: consensusRaw.map((c) => c.toString()).toList(),
        divergencePoints: divergenceRaw.map((d) => d.toString()).toList(),
        comparativeSummary: data['comparative_summary'] as String? ?? '',
        grounding: data['grounding'] as String? ?? 'abstract',
        modelId: data['model_id'] as String? ?? '',
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
