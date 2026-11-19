import 'package:athena/core/prefs/user_preferences.dart';
import 'package:athena/core/widgets/command_palette_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await UserPreferences.instance.load(force: true);
    await UserPreferences.instance.clearSearchHistory();
  });

  group('CommandPaletteDialog', () {
    testWidgets('renders search field, destinations, and keyboard hints',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommandPaletteDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Home Research Feed'), findsOneWidget);
      expect(find.text('Search Corpus & Web'), findsOneWidget);
      expect(find.text('Taxonomy & Fields'), findsOneWidget);
      expect(find.text('Weekly Research Digest'), findsOneWidget);
      expect(find.text('My Library & Collections'), findsOneWidget);
      expect(find.text('Downloads & Offline Storage'), findsOneWidget);
      expect(find.text('Paper Comparison Matrix'), findsOneWidget);

      expect(find.text('⌘K'), findsOneWidget);
      expect(find.text('Athena Command Palette'), findsOneWidget);
    });

    testWidgets('filters destinations when user enters text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommandPaletteDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter query 'digest'
      await tester.enterText(find.byType(TextField), 'digest');
      await tester.pumpAndSettle();

      expect(find.text('Weekly Research Digest'), findsOneWidget);
      expect(find.text('Home Research Feed'), findsNothing);
      expect(find.text('Search literature for "digest"'), findsOneWidget);
    });

    testWidgets('displays recent searches when search history is available',
        (tester) async {
      await UserPreferences.instance.addSearchHistory('quantum computing');
      await UserPreferences.instance.addSearchHistory('transformer attention');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommandPaletteDialog(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RECENT RESEARCH QUERIES'), findsOneWidget);
      expect(find.text('quantum computing'), findsOneWidget);
      expect(find.text('transformer attention'), findsOneWidget);
    });
  });
}
