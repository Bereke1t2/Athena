import 'package:athena/core/widgets/paper_card.dart';
import 'package:athena/features/papers/domain/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaperSummary createPaper({
    required bool isSeminal,
    double authorityScore = 0.0,
    bool hasCode = false,
  }) {
    return PaperSummary(
      id: '0197c0de-0000-7000-8000-000000000001',
      title: 'Attention Is All You Need',
      abstract: 'The dominant sequence transduction models are based on complex recurrent networks.',
      publishedOn: DateTime.utc(2017, 6, 12),
      year: 2017,
      venueName: 'NeurIPS',
      publicationType: 'conference_paper',
      oaStatus: 'gold',
      isOpenAccess: true,
      citedByCount: 120000,
      authorityScore: authorityScore,
      isSeminal: isSeminal,
      hasCode: hasCode,
    );
  }

  testWidgets('renders Seminal badge when paper.isSeminal is true', (tester) async {
    final paper = createPaper(isSeminal: true, authorityScore: 98.5);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperCard(paper: paper),
        ),
      ),
    );

    expect(find.byKey(const Key('seminal-paper-badge')), findsOneWidget);
    expect(find.text('Seminal'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
  });

  testWidgets('does not render Seminal badge when paper.isSeminal is false', (tester) async {
    final paper = createPaper(isSeminal: false, authorityScore: 12.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperCard(paper: paper),
        ),
      ),
    );

    expect(find.byKey(const Key('seminal-paper-badge')), findsNothing);
    expect(find.text('Seminal'), findsNothing);
  });

  testWidgets('renders Code badge when paper.hasCode is true', (tester) async {
    final paper = createPaper(isSeminal: false, hasCode: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperCard(paper: paper),
        ),
      ),
    );

    expect(find.byKey(const Key('code-available-badge')), findsOneWidget);
    expect(find.text('Code'), findsOneWidget);
    expect(find.byIcon(Icons.code_rounded), findsOneWidget);
  });

  testWidgets('does not render Code badge when paper.hasCode is false', (tester) async {
    final paper = createPaper(isSeminal: false, hasCode: false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaperCard(paper: paper),
        ),
      ),
    );

    expect(find.byKey(const Key('code-available-badge')), findsNothing);
    expect(find.text('Code'), findsNothing);
  });
}
