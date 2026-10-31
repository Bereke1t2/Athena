import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/di.dart';
import '../domain/paper.dart';

part 'paper_detail_notifier.g.dart';

@riverpod
class PaperDetailController extends _$PaperDetailController {
  @override
  Future<PaperDetail> build(String id) {
    return ref.watch(paperRepositoryProvider).getById(id);
  }
}

@riverpod
Future<List<PaperSummary>> paperCitations(
  Ref ref,
  String id, {
  String direction = 'in',
}) async {
  final repo = ref.watch(paperRepositoryProvider);
  final items = await repo.getCitations(id, direction: direction);
  if (items.isEmpty) {
    try {
      final related = await repo.getRelated(id, limit: 10);
      if (related.isNotEmpty) return related;
    } catch (_) {}
  }
  return items;
}

@riverpod
Future<List<PaperSummary>> paperRelated(Ref ref, String id) {
  return ref.watch(paperRepositoryProvider).getRelated(id);
}

