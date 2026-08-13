import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/screens/ai_assistant_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiAssistantScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('with no API key it still works, and says so', (tester) async {
    await pump(tester);

    // A banner, not a wall — offline answers are still available.
    expect(find.textContaining('No AI key yet'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the chat stays usable without a key', (tester) async {
    await pump(tester);

    // The input must be there: simple questions are answered from the
    // shop's own records with no AI involved.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Business insights kaatu'),
        findsOneWidget);
  });

  testWidgets('offers questions in Tamil, Tanglish and English',
      (tester) async {
    await pump(tester);

    expect(find.text('Intha maasam profit evvalavu?'), findsOneWidget);
    expect(find.text('இந்த மாதம் எந்த பொருளில் லாபம் அதிகம்?'), findsOneWidget);

    // The English one sits below the fold in a lazily-built list.
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();
    expect(find.text('What should I do to increase profit?'), findsOneWidget);
  });

  testWidgets('the language switcher lists all four choices', (tester) async {
    await pump(tester);

    // Defaults to Auto.
    expect(find.text('Auto'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();

    expect(find.text('தமிழ்'), findsOneWidget);
    expect(find.text('Tanglish'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a language does not crash when offline', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    // Saving to Firestore fails in this environment; the choice must still
    // apply for the session instead of throwing.
    expect(find.text('English'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
