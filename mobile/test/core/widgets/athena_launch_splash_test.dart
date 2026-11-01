import 'package:athena/core/widgets/athena_launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AthenaLaunchSplash', () {
    testWidgets('renders aperture logo, brand title, and underlying child',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AthenaLaunchSplash(
            autoStart: false,
            child: Scaffold(
              body: Text('Workspace Home Content'),
            ),
          ),
        ),
      );

      // Both the underlying view and the splash overlay are in the tree
      expect(find.text('Workspace Home Content'), findsOneWidget);
      expect(find.text('ATHENA'), findsOneWidget);
      expect(find.text('Tap anywhere to start'), findsOneWidget);
      expect(find.byType(AthenaAnimatedOpeningLogo), findsOneWidget);
    });

    testWidgets('tap dismisses the splash overlay and invokes onCompleted',
        (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AthenaLaunchSplash(
            autoStart: true,
            duration: const Duration(milliseconds: 2000),
            onCompleted: () => completed = true,
            child: const Scaffold(
              body: Text('Workspace Home Content'),
            ),
          ),
        ),
      );

      expect(find.text('ATHENA'), findsOneWidget);
      expect(completed, isFalse);

      // Tap on the splash screen to trigger early completion
      await tester.tap(find.text('Tap anywhere to start'));
      await tester.pump();

      expect(completed, isTrue);
      // Splash overlay dismissed, main content remains
      expect(find.text('Workspace Home Content'), findsOneWidget);
      expect(find.byType(AthenaAnimatedOpeningLogo), findsNothing);
    });

    testWidgets('animates through rotation, aperture opening, and dissolves',
        (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AthenaLaunchSplash(
            autoStart: true,
            duration: const Duration(milliseconds: 1000),
            onCompleted: () => completed = true,
            child: const Scaffold(
              body: Text('Main Screen'),
            ),
          ),
        ),
      );

      expect(find.text('Main Screen'), findsOneWidget);
      expect(find.byType(AthenaAnimatedOpeningLogo), findsOneWidget);

      // Advance through deceleration and opening
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(AthenaAnimatedOpeningLogo), findsOneWidget);

      // Advance past completion
      await tester.pump(const Duration(milliseconds: 400));
      expect(completed, isTrue);
      expect(find.byType(AthenaAnimatedOpeningLogo), findsNothing);
      expect(find.text('Main Screen'), findsOneWidget);
    });
  });

  group('AthenaAnimatedOpeningLogo', () {
    testWidgets('renders custom paints for halo, emblem, and glow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AthenaAnimatedOpeningLogo(
                rotation: 1.57, // 90 degrees
                openFactor: 0.5,
                size: 80,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AthenaAnimatedOpeningLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
