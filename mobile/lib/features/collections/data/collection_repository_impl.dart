import 'package:dio/dio.dart';

import '../domain/collection.dart';
import '../domain/collection_repository.dart';
import 'collection_dto.dart';

class CollectionRepositoryImpl implements CollectionRepository {
  CollectionRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<List<Collection>> listCollections() async {
    final res = await _dio.get<Map<String, dynamic>>('/collections');
    final data = res.data!;
    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    return itemsRaw.map((raw) {
      final dto = CollectionDto.fromJson((raw as Map).cast<String, dynamic>());
      return dto.toDomain();
    }).toList();
  }

  @override
  Future<(Collection, List<CollectionPaper>)> getCollection(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/collections/$id');
    final data = res.data!;

    final colMap = (data['collection'] as Map).cast<String, dynamic>();
    final collection = CollectionDto.fromJson(colMap).toDomain();

    final papersRaw = (data['papers'] as List<dynamic>?) ?? [];
    final papers = papersRaw.map((raw) {
      final dto = CollectionPaperDto.fromJson((raw as Map).cast<String, dynamic>());
      return dto.toDomain();
    }).toList();

    return (collection, papers);
  }

  @override
  Future<Collection> createCollection({
    required String name,
    String description = '',
    String color = '#6366F1',
    bool isPublic = false,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/collections',
      data: {
        'name': name,
        'description': description,
        'color': color,
        'is_public': isPublic,
      },
    );
    final data = res.data!;
    return CollectionDto.fromJson(data).toDomain();
  }

  @override
  Future<Collection> updateCollection(
    String id, {
    String? name,
    String? description,
    String? color,
    bool? isPublic,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (description != null) payload['description'] = description;
    if (color != null) payload['color'] = color;
    if (isPublic != null) payload['is_public'] = isPublic;

    final res = await _dio.patch<Map<String, dynamic>>(
      '/collections/$id',
      data: payload,
    );
    final data = res.data!;
    return CollectionDto.fromJson(data).toDomain();
  }

  @override
  Future<void> deleteCollection(String id) async {
    await _dio.delete<void>('/collections/$id');
  }

  @override
  Future<void> addPaper(String collectionId, String paperId, {String note = ''}) async {
    await _dio.post<void>(
      '/collections/$collectionId/papers',
      data: {
        'paper_id': paperId,
        'note': note,
      },
    );
  }

  @override
  Future<void> removePaper(String collectionId, String paperId) async {
    await _dio.delete<void>('/collections/$collectionId/papers/$paperId');
  }

  @override
  Future<String> exportCollection(String collectionId, {String format = 'bibtex'}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/collections/$collectionId/export',
      queryParameters: {'format': format},
    );
    final data = res.data!;
    return (data['content'] as String?) ?? '';
  }

  @override
  Future<List<PaperMembership>> getPaperMemberships(String paperId) async {
    final res = await _dio.get<Map<String, dynamic>>('/papers/$paperId/collections');
    final data = res.data!;
    final itemsRaw = (data['items'] as List<dynamic>?) ?? [];
    return itemsRaw.map((raw) {
      final dto = PaperMembershipDto.fromJson((raw as Map).cast<String, dynamic>());
      return dto.toDomain();
    }).toList();
  }
}
