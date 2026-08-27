import 'search.dart';

abstract interface class SearchRepository {
  Future<SearchPage> search(SearchFilters filters, {String? cursor, int limit});
}
