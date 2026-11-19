import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/features/comparison/domain/comparison_tray_models.dart';
import 'package:athena/features/comparison/presentation/comparison_tray_notifier.dart';
import 'package:athena/features/comparison/presentation/widgets/comparison_tray_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load(force: true);
  });

  group('ComparisonTrayBar', () {
    testWidgets('renders nothing when comparison tray is empty',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ComparisonTrayBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compare Papers'), findsNothing);
      expect(find.byIcon(Icons.compare_arrows_rounded), findsNothing);
    });

    testWidgets('renders collapsed pill with count and status when populated',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(comparisonTrayProvider.notifier).addPaper(
            const ComparisonTrayItem(
              paperId: 'p1',
              title: 'Attention Is All You Need',
              year: 2017,
              venue: 'NeurIPS',
            ),
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ComparisonTrayBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compare Papers'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('Select 1 more paper to compare'), findsOneWidget);
      // Since only 1 paper, "Compare" filled button is not shown in collapsed pill
      expect(find.widgetWithText(FilledButton, 'Compare'), findsNothing);
    });

    testWidgets(
        'renders Compare action when 2+ papers are selected and allows expanding',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(comparisonTrayProvider.notifier);
      notifier.addPaper(
        const ComparisonTrayItem(
          paperId: 'p1',
          title: 'Attention Is All You Need',
          year: 2017,
          venue: 'NeurIPS',
        ),
      );
      notifier.addPaper(
        const ComparisonTrayItem(
          paperId: 'p2',
          title: 'BERT: Pre-training of Deep Bidirectional Transformers',
          year: 2018,
          venue: 'NAACL',
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ComparisonTrayBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('2 papers selected for synthesis'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Compare'), findsOneWidget);

      // Tap expand chevron
      await tester.tap(find.byTooltip('Expand comparison tray'));
      await tester.pumpAndSettle();

      // Expanded tray view appears
      expect(find.text('COMPARISON TRAY'), findsOneWidget);
      expect(find.text('Attention Is All You Need'), findsOneWidget);
      expect(find.text('BERT: Pre-training of Deep Bidirectional Transformers'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Compare (2)'), findsOneWidget);

      // Tap Clear All
      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();

      // Tray becomes empty and collapses
      expect(find.text('COMPARISON TRAY'), findsNothing);
      expect(find.text('Compare Papers'), findsNothing);
    });

    testWidgets('allows removing an individual paper from expanded tray',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(comparisonTrayProvider.notifier);
      notifier.addPaper(
        const ComparisonTrayItem(paperId: 'p1', title: 'Paper Alpha'),
      );
      notifier.addPaper(
        const ComparisonTrayItem(paperId: 'p2', title: 'Paper Beta'),
      );
      notifier.setExpanded(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ComparisonTrayBar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Paper Alpha'), findsOneWidget);
      expect(find.text('Paper Beta'), findsOneWidget);

      // Find remove button for Paper Alpha (close icon)
      final closeIcons = find.byIcon(Icons.close_rounded);
      expect(closeIcons, findsNWidgets(2)); // 2 paper cards

      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      // Only Paper Beta remains
      expect(find.text('Paper Alpha'), findsNothing);
      expect(find.text('Paper Beta'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
    });
  });
}
