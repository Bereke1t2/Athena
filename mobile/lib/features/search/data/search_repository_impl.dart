import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../domain/search.dart';
import '../domain/search_repository.dart';
import 'search.dtos.dart';

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._dio);

  final Dio _dio;

  @override
  Future<SearchPage> search(SearchFilters filters, {String? cursor, int limit = 20}) async {
    try {
      final isLive = filters.isLive;
      final endpoint = isLive ? '/search/live' : '/search';
      final timeout = isLive ? Timeouts.federatedSearch : Timeouts.receive;

      final queryParams = <String, dynamic>{
        'q': filters.query,
        'sort': filters.sort.wireValue,
        if (filters.openAccess != null) 'open_access': filters.openAccess!,
        if (filters.minCitations != null && filters.minCitations! > 0)
          'min_citations': filters.minCitations!,
        if (!isLive && cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'limit': limit,
      };

      final res = await _dio.get<Map<String, dynamic>>(
        endpoint,
        queryParameters: queryParams,
        options: Options(receiveTimeout: timeout),
      );
      final body = SearchListDto.fromJson(res.data!);
      return SearchPage(
        items: body.items.map((e) => e.toDomain()).toList(),
        nextCursor: isLive ? null : body.meta.nextCursor,
        modeUsed: isLive ? 'live' : (body.meta.modeUsed ?? 'keyword'),
        totalEstimate: body.meta.totalEstimate >= 0
            ? body.meta.totalEstimate
            : body.items.length,
        sources:
            (body.meta.sources ?? const []).map((e) => e.toDomain()).toList(),
        tookMs: body.meta.tookMs,
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
