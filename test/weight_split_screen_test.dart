import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/screens/weight_split_screen.dart';

void main() {
  testWidgets('renders, calculates and matches the measured total',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WeightSplitScreen()));
    await tester.pump(); // let the (failing, offline) product load settle
    expect(tester.takeException(), isNull);

    // Measured total
    await tester.enterText(find.byType(TextField).first, '98');

    // First product row
    await tester.enterText(find.widgetWithText(TextField, 'Product name'), 'A');
    await tester.enterText(find.widgetWithText(TextField, 'Pieces'), '200');
    await tester.enterText(
        find.widgetWithText(TextField, 'Approx g/pc'), '400');
    await tester.enterText(find.widgetWithText(TextField, 'Max g/pc'), '420');
    await tester.pump();

    await tester.tap(find.text('Calculate split'));
    await tester.pumpAndSettle();

    expect(find.text('Split result'), findsOneWidget);
    expect(find.text('Matches the measured total exactly'), findsOneWidget);
    expect(find.text('98.000'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an error when nothing is entered', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WeightSplitScreen()));
    await tester.pump();
    await tester.tap(find.text('Calculate split'));
    await tester.pump();
    expect(find.text('Enter the measured total weight in kg'), findsOneWidget);
  });
}
