import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/prefs/user_preferences.dart';
import '../domain/annotation.dart';
import '../domain/annotation_repository.dart';
import 'annotation_dto.dart';

class AnnotationRepositoryImpl implements AnnotationRepository {
  AnnotationRepositoryImpl(this._dio, [UserPreferences? prefs])
      : _prefs = prefs ?? UserPreferences.instance;

  final Dio _dio;
  final UserPreferences _prefs;

  @override
  Future<List<Annotation>> listAnnotations(String paperId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/papers/$paperId/annotations');
      final data = res.data;
      if (data != null && data['items'] is List) {
        final itemsRaw = data['items'] as List<dynamic>;
        final annotations = itemsRaw.map((raw) {
          final dto = AnnotationDto.fromJson((raw as Map).cast<String, dynamic>());
          return dto.toDomain();
        }).toList();

        // Update local cache
        await _saveLocalCache(paperId, annotations);
        return annotations;
      }
    } catch (_) {
      // Offline fallback: load from local storage cache
    }

    return _loadLocalCache(paperId);
  }

  @override
  Future<Annotation> createAnnotation(CreateAnnotationParams params) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/papers/${params.paperId}/annotations',
        data: {
          'page_number': params.pageNumber,
          'section_index': params.sectionIndex,
          'selected_text': params.selectedText,
          'note': params.note,
          'color': params.color.code,
        },
      );
      final data = res.data;
      if (data != null) {
        final created = AnnotationDto.fromJson(data).toDomain();
        final current = _loadLocalCache(params.paperId);
        final updated = [created, ...current.where((a) => a.id != created.id)];
        await _saveLocalCache(params.paperId, updated);
        return created;
      }
    } catch (_) {
      // Fallback: save locally
    }

    final localAnnotation = Annotation(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      userId: _prefs.userId ?? 'local_user',
      paperId: params.paperId,
      pageNumber: params.pageNumber,
      sectionIndex: params.sectionIndex,
      selectedText: params.selectedText,
      note: params.note,
      color: params.color,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final current = _loadLocalCache(params.paperId);
    final updated = [localAnnotation, ...current];
    await _saveLocalCache(params.paperId, updated);
    return localAnnotation;
  }

  @override
  Future<Annotation> updateAnnotation(UpdateAnnotationParams params) async {
    final payload = <String, dynamic>{};
    if (params.note != null) payload['note'] = params.note;
    if (params.color != null) payload['color'] = params.color!.code;

    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/annotations/${params.id}',
        data: payload,
      );
      final data = res.data;
      if (data != null) {
        final updated = AnnotationDto.fromJson(data).toDomain();
        final current = _loadLocalCache(params.paperId);
        final list = current.map((a) => a.id == updated.id ? updated : a).toList();
        await _saveLocalCache(params.paperId, list);
        return updated;
      }
    } catch (_) {
      // Fallback: update locally
    }

    final current = _loadLocalCache(params.paperId);
    Annotation? found;
    final list = current.map((a) {
      if (a.id == params.id) {
        found = a.copyWith(
          note: params.note ?? a.note,
          color: params.color ?? a.color,
          updatedAt: DateTime.now(),
        );
        return found!;
      }
      return a;
    }).toList();

    if (found != null) {
      await _saveLocalCache(params.paperId, list);
      return found!;
    }

    throw Exception('Annotation not found');
  }

  @override
  Future<void> deleteAnnotation({required String id, required String paperId}) async {
    try {
      await _dio.delete<void>('/annotations/$id');
    } catch (_) {
      // Fallback: delete locally even if offline/guest
    }

    final current = _loadLocalCache(paperId);
    final updated = current.where((a) => a.id != id).toList();
    await _saveLocalCache(paperId, updated);
  }

  List<Annotation> _loadLocalCache(String paperId) {
    final raw = _prefs.getPaperAnnotations(paperId);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => Annotation.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocalCache(String paperId, List<Annotation> annotations) async {
    try {
      final raw = jsonEncode(annotations.map((a) => a.toJson()).toList());
      await _prefs.setPaperAnnotations(paperId, raw);
    } catch (_) {}
  }
}
