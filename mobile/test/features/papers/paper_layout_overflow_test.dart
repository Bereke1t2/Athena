import 'package:athena/core/widgets/paper_card.dart';
import 'package:athena/features/ai/presentation/create_audio_screen.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PaperCard renders without overflow on narrow screen and high text scale', (tester) async {
    // Set narrow screen: 320x568 (iPhone SE 1st gen size)
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const mockPaper = PaperSummary(
      id: 'paper-12345678-long-id',
      title: 'A Very Long Complex Multi-Line Paper Title Exploring Deep Generative Architectures In Constrained Resource Environments',
      abstract: 'This is an extensive abstract detailing the methodological breakthroughs and experimental evaluations performed across multiple domain benchmarks.',
      publishedOn: null,
      year: 2026,
      venueName: 'International Conference on Learning Representations and Advanced Machine Learning Systems',
      publicationType: 'conference_paper',
      oaStatus: 'gold',
      isOpenAccess: true,
      citedByCount: 1482,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PaperCard(
                paper: mockPaper,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(PaperCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CreateAudioScreen renders without overflow on 320px screen width', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 600),
              textScaler: TextScaler.linear(1.3),
            ),
            child: CreateAudioScreen(
              paperId: 'paper-12345',
              initialTitle: 'Very Long Research Title Exceeding Single Line Display Bounds',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(CreateAudioScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
