import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../papers/data/paper.dtos.dart';
import '../../papers/domain/paper.dart';
import '../domain/digest_models.dart';
import '../domain/digest_repository.dart';

class DigestRepositoryImpl implements DigestRepository {
  DigestRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<UserDigest> getLatestDigest() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/research/digest/latest');
      return _parseDigest(res.data!);
    } catch (e) {
      throw failureFromDio(e);
    }
  }

  @override
  Future<UserDigest> generateDigest({String frequency = 'weekly'}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/research/digest/generate',
        data: {'frequency': frequency},
      );
      return _parseDigest(res.data!);
    } catch (e) {
      throw failureFromDio(e);
    }
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
      final papers = <PaperSummary>[];

      for (final raw in papersRaw) {
        if (raw is! Map) continue;
        try {
          final paperMap = Map<String, dynamic>.from(raw);
          final id = (paperMap['id'] ?? paperMap['ID'] ?? '').toString();
          final title = (paperMap['title'] ?? paperMap['Title'] ?? 'Untitled').toString();
          final abstractText = paperMap['abstract'] ?? paperMap['Abstract'];
          final pubYear = (paperMap['publication_year'] ?? paperMap['year'] ?? paperMap['Year'] ?? DateTime.now().year) as num;

          Map<String, dynamic> venueMap;
          if (paperMap['venue'] is Map) {
            venueMap = Map<String, dynamic>.from(paperMap['venue'] as Map);
          } else {
            final venueName = (paperMap['venue_name'] ?? paperMap['VenueName'] ?? '').toString();
            venueMap = {'name': venueName};
          }

          final normalized = <String, dynamic>{
            'id': id,
            'title': title,
            if (abstractText != null) 'abstract': abstractText.toString(),
            if (paperMap['publication_date'] != null || paperMap['PublishedOn'] != null)
              'publication_date': (paperMap['publication_date'] ?? paperMap['PublishedOn']).toString(),
            'publication_year': pubYear.toInt(),
            'venue': venueMap,
            'publication_type': (paperMap['publication_type'] ?? paperMap['PublicationType'] ?? 'article').toString(),
            'oa_status': (paperMap['oa_status'] ?? paperMap['OAStatus'] ?? 'closed').toString(),
            'is_open_access': (paperMap['is_open_access'] ?? paperMap['IsOpenAccess'] ?? false) == true,
            'cited_by_count': ((paperMap['cited_by_count'] ?? paperMap['CitedByCount'] ?? 0) as num).toInt(),
          };

          final dto = PaperSummaryDto.fromJson(normalized);
          papers.add(dto.toDomain());
        } catch (_) {
          // Gracefully skip single malformed item without crashing whole digest
          continue;
        }
      }

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
