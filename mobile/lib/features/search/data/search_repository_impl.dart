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
      // Federated live search: fans out to every research provider server-side
      // and returns the merged, ranked union. Needs a longer receive timeout
      // than ordinary endpoints.
      final res = await _dio.get<Map<String, dynamic>>(
        '/search/live',
        queryParameters: {
          'q': filters.query,
          'sort': filters.sort.wireValue,
          if (filters.openAccess != null) 'open_access': filters.openAccess!,
          if (filters.minCitations != null && filters.minCitations! > 0)
            'min_citations': filters.minCitations!,
          'limit': limit,
        },
        options: Options(receiveTimeout: Timeouts.federatedSearch),
      );
      final body = SearchListDto.fromJson(res.data!);
      return SearchPage(
        items: body.items.map((e) => e.toDomain()).toList(),
        nextCursor: null, // live search is a single merged page
        modeUsed: 'live',
        totalEstimate: body.items.length,
        sources:
            (body.meta.sources ?? const []).map((e) => e.toDomain()).toList(),
        tookMs: body.meta.tookMs,
      );
    } catch (e) {
      throw failureFromDio(e);
    }
  }
}
