import 'dart:convert';
import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/comparison/domain/comparison_tray_models.dart';
import 'package:athena/features/comparison/presentation/comparison_tray_notifier.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load(force: true);
    await UserPreferences.instance.clearComparisonTray();
  });

  group('ComparisonTrayNotifier', () {
    test('initializes empty when storage is clear', () {
      final notifier = ComparisonTrayNotifier();
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.isExpanded, isFalse);
    });

    test('restores saved items from UserPreferences', () async {
      final initialData = [
        const ComparisonTrayItem(
          paperId: 'paper-a',
          title: 'Paper Alpha',
          year: 2024,
          venue: 'ICLR',
        ).toJson(),
        const ComparisonTrayItem(
          paperId: 'paper-b',
          title: 'Paper Beta',
          year: 2025,
          venue: 'CVPR',
        ).toJson(),
      ];
      await UserPreferences.instance
          .setComparisonTrayJson(jsonEncode(initialData));

      final notifier = ComparisonTrayNotifier();
      expect(notifier.state.items.length, 2);
      expect(notifier.state.items[0].paperId, 'paper-a');
      expect(notifier.state.items[1].paperId, 'paper-b');
      expect(notifier.state.canCompare, isTrue);
    });

    test('addPaper appends paper, forbids duplicates, and caps at 4', () async {
      final notifier = ComparisonTrayNotifier();

      const p1 = ComparisonTrayItem(paperId: 'p1', title: 'Paper 1');
      const p2 = ComparisonTrayItem(paperId: 'p2', title: 'Paper 2');
      const p3 = ComparisonTrayItem(paperId: 'p3', title: 'Paper 3');
      const p4 = ComparisonTrayItem(paperId: 'p4', title: 'Paper 4');
      const p5 = ComparisonTrayItem(paperId: 'p5', title: 'Paper 5');

      expect(notifier.addPaper(p1), isTrue);
      expect(notifier.state.count, 1);

      // Duplicate should fail
      expect(notifier.addPaper(p1), isFalse);
      expect(notifier.state.count, 1);

      expect(notifier.addPaper(p2), isTrue);
      expect(notifier.addPaper(p3), isTrue);
      expect(notifier.addPaper(p4), isTrue);
      expect(notifier.state.count, 4);
      expect(notifier.state.isFull, isTrue);

      // 5th paper rejected
      expect(notifier.addPaper(p5), isFalse);
      expect(notifier.state.count, 4);

      // Check persisted in storage
      await pumpEventQueue();
      final storedRaw = UserPreferences.instance.comparisonTrayJson;
      expect(storedRaw, isNotNull);
      final decoded = jsonDecode(storedRaw!) as List;
      expect(decoded.length, 4);
    });

    test('removePaper removes item and auto-collapses when empty', () async {
      final notifier = ComparisonTrayNotifier();
      const p1 = ComparisonTrayItem(paperId: 'p1', title: 'Paper 1');
      const p2 = ComparisonTrayItem(paperId: 'p2', title: 'Paper 2');

      notifier.addPaper(p1);
      notifier.addPaper(p2);
      notifier.setExpanded(true);
      expect(notifier.state.isExpanded, isTrue);

      notifier.removePaper('p1');
      expect(notifier.state.count, 1);
      expect(notifier.state.containsPaper('p1'), isFalse);
      expect(notifier.state.isExpanded, isTrue);

      // Removing last item collapses tray
      notifier.removePaper('p2');
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.isExpanded, isFalse);
      await pumpEventQueue();
      expect(UserPreferences.instance.comparisonTrayJson, isNull);
    });

    test('togglePaper adds if absent, removes if present', () {
      final notifier = ComparisonTrayNotifier();
      const p1 = ComparisonTrayItem(paperId: 'p1', title: 'Paper 1');

      final added = notifier.togglePaper(p1);
      expect(added, isTrue);
      expect(notifier.state.containsPaper('p1'), isTrue);

      final removed = notifier.togglePaper(p1);
      expect(removed, isFalse);
      expect(notifier.state.containsPaper('p1'), isFalse);
    });

    test('clear resets items, collapses, and purges storage', () async {
      final notifier = ComparisonTrayNotifier();
      notifier.addPaper(const ComparisonTrayItem(paperId: 'p1', title: 'Paper 1'));
      notifier.setExpanded(true);

      notifier.clear();
      expect(notifier.state.items, isEmpty);
      expect(notifier.state.isExpanded, isFalse);
      await pumpEventQueue();
      expect(UserPreferences.instance.comparisonTrayJson, isNull);
    });

    test('toggleExpanded flips boolean state', () {
      final notifier = ComparisonTrayNotifier();
      expect(notifier.state.isExpanded, isFalse);

      notifier.toggleExpanded();
      expect(notifier.state.isExpanded, isTrue);

      notifier.toggleExpanded();
      expect(notifier.state.isExpanded, isFalse);
    });
  });
}
