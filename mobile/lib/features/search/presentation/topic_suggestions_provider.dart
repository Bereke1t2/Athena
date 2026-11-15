import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di.dart';
import '../../topics/domain/topic.dart';

/// Live topic autocomplete suggestions matching the active search query.
final topicSuggestionsProvider =
    FutureProvider.autoDispose.family<List<Topic>, String>((ref, query) async {
  final q = query.trim();
  if (q.length < 2) return const [];
  final repo = ref.watch(topicsRepositoryProvider);
  try {
    final page = await repo.list(query: q, limit: 6);
    return page.items;
  } catch (_) {
    return const [];
  }
});
