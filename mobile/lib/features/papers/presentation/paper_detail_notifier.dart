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
