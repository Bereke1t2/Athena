import 'package:athena/features/comparison/domain/comparison_tray_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ComparisonTrayItem', () {
    test('JSON serialization and deserialization roundtrip', () {
      const item = ComparisonTrayItem(
        paperId: 'paper-123',
        title: 'Attention Is All You Need',
        authors: ['Vaswani', 'Shazeer', 'Parmar'],
        year: 2017,
        venue: 'NeurIPS',
      );

      final json = item.toJson();
      expect(json['paper_id'], 'paper-123');
      expect(json['title'], 'Attention Is All You Need');
      expect(json['authors'], ['Vaswani', 'Shazeer', 'Parmar']);
      expect(json['year'], 2017);
      expect(json['venue'], 'NeurIPS');

      final reconstructed = ComparisonTrayItem.fromJson(json);
      expect(reconstructed.paperId, item.paperId);
      expect(reconstructed.title, item.title);
      expect(reconstructed.authors, item.authors);
      expect(reconstructed.year, item.year);
      expect(reconstructed.venue, item.venue);
      expect(reconstructed, equals(item));
    });

    test('fromJson handles null and missing fields gracefully', () {
      final item = ComparisonTrayItem.fromJson(const {});
      expect(item.paperId, '');
      expect(item.title, '');
      expect(item.authors, isEmpty);
      expect(item.year, 0);
      expect(item.venue, '');
    });
  });

  group('ComparisonTrayState', () {
    test('default state has empty items and is not expanded', () {
      const state = ComparisonTrayState();
      expect(state.items, isEmpty);
      expect(state.isExpanded, isFalse);
      expect(state.canCompare, isFalse);
      expect(state.isFull, isFalse);
      expect(state.count, 0);
      expect(state.paperIds, isEmpty);
    });

    test('canCompare is true when items >= 2', () {
      const p1 = ComparisonTrayItem(paperId: 'p1', title: 'Paper 1');
      const p2 = ComparisonTrayItem(paperId: 'p2', title: 'Paper 2');

      const single = ComparisonTrayState(items: [p1]);
      expect(single.canCompare, isFalse);

      const dual = ComparisonTrayState(items: [p1, p2]);
      expect(dual.canCompare, isTrue);
      expect(dual.count, 2);
      expect(dual.paperIds, ['p1', 'p2']);
      expect(dual.containsPaper('p1'), isTrue);
      expect(dual.containsPaper('p3'), isFalse);
    });

    test('isFull is true when 4 papers are present', () {
      final items = List.generate(
        4,
        (i) => ComparisonTrayItem(paperId: 'p$i', title: 'Paper $i'),
      );
      final state = ComparisonTrayState(items: items);
      expect(state.isFull, isTrue);
      expect(state.count, 4);
    });

    test('copyWith updates specified fields', () {
      const p1 = ComparisonTrayItem(paperId: 'p1', title: 'Paper 1');
      const state = ComparisonTrayState();

      final updated = state.copyWith(items: [p1], isExpanded: true);
      expect(updated.items.length, 1);
      expect(updated.isExpanded, isTrue);
    });
  });
}
