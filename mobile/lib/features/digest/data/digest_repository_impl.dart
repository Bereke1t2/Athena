import 'package:dio/dio.dart';

import '../../papers/data/paper.dtos.dart';
import '../domain/digest_models.dart';
import '../domain/digest_repository.dart';

class DigestRepositoryImpl implements DigestRepository {
  DigestRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserDigest> getLatestDigest() async {
    final res = await _dio.get<Map<String, dynamic>>('/research/digest/latest');
    return _parseDigest(res.data!);
  }

  @override
  Future<UserDigest> generateDigest({String frequency = 'weekly'}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/research/digest/generate',
      data: {'frequency': frequency},
    );
    return _parseDigest(res.data!);
  }

  UserDigest _parseDigest(Map<String, dynamic> data) {
    final pulsesRaw = (data['pulses'] as List<dynamic>?) ?? [];
    final pulses = pulsesRaw.map((p) {
      final map = p as Map<String, dynamic>;
      final themesRaw = (map['key_themes'] as List<dynamic>?) ?? [];
      return TopicPulse(
        topicSlug: map['topic_slug'] as String? ?? '',
        topicName: map['topic_name'] as String? ?? '',
        paperCount: (map['paper_count'] as num?)?.toInt() ?? 0,
        velocity: (map['velocity'] as num?)?.toDouble() ?? 0.0,
        keyThemes: themesRaw.map((e) => e.toString()).toList(),
      );
    }).toList();

    final sectionsRaw = (data['sections'] as List<dynamic>?) ?? [];
    final sections = sectionsRaw.map((s) {
      final map = s as Map<String, dynamic>;
      final papersRaw = (map['papers'] as List<dynamic>?) ?? [];
      final papers = papersRaw.map((raw) {
        final dto = PaperSummaryDto.fromJson((raw as Map).cast<String, dynamic>());
        return dto.toDomain();
      }).toList();

      return DigestSection(
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        papers: papers,
      );
    }).toList();

    final takeawaysRaw = (data['top_takeaways'] as List<dynamic>?) ?? [];
    final takeaways = takeawaysRaw.map((e) => e.toString()).toList();

    return UserDigest(
      id: data['id'] as String? ?? '',
      generatedAt: DateTime.tryParse(data['generated_at'] as String? ?? '') ?? DateTime.now(),
      frequency: data['frequency'] as String? ?? 'weekly',
      pulses: pulses,
      sections: sections,
      topTakeaways: takeaways,
    );
  }
}
