import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/paper.dart';
import '../domain/paper_repository.dart';
import 'paper.dtos.dart';

class PaperRepositoryImpl implements PaperRepository {
  PaperRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<PaperDetail> getById(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/research/papers/$id');
      return PaperDetailDto.fromJson(res.data!).toDomain();
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
