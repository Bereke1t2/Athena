import 'package:athena/core/widgets/ai_formatted_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiFormattedText', () {
    testWidgets('renders single-line display math formatted with \$\$', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiFormattedText(
              text: r'$$E = mc^2$$',
            ),
          ),
        ),
      );

      expect(find.byType(Math), findsOneWidget);
    });

    testWidgets('renders multi-line display math block', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiFormattedText(
              text: "Here is the equation:\n\$\$\n\\nabla \\times \\mathbf{B} = \\mu_0\\mathbf{J}\n\$\$\nEnd of equation.",
            ),
          ),
        ),
      );

      expect(find.textContaining('Here is the equation:'), findsOneWidget);
      expect(find.byType(Math), findsOneWidget);
      expect(find.textContaining('End of equation.'), findsOneWidget);
    });

    testWidgets('renders inline math and currency correctly without conflict', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiFormattedText(
              text: r'The cost was $100 and the formula was $x + y = z$.',
            ),
          ),
        ),
      );

      // Math $x + y = z$ rendered via flutter_math
      expect(find.byType(Math), findsOneWidget);
    });

    testWidgets('renders code block with language header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiFormattedText(
              text: "```python\ndef hello():\n    print('world')\n```",
            ),
          ),
        ),
      );

      expect(find.text('PYTHON'), findsOneWidget);
      expect(find.textContaining("def hello():"), findsOneWidget);
    });
  });
}
