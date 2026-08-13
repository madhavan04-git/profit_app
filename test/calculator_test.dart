import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/screens/calculator_screen.dart';

void main() {
  setUp(CalcHistory.clear);

  Future<void> pumpCalc(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalculatorScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, List<String> keys) async {
    for (final k in keys) {
      await tester.tap(find.widgetWithText(InkWell, k).last);
      await tester.pump();
    }
  }

  testWidgets('renders without layout errors', (tester) async {
    await pumpCalc(tester);
    expect(tester.takeException(), isNull);
    // All 20 keys are on screen.
    for (final k in ['C', '⌫', '%', '÷', '7', '8', '9', '×', '4', '5', '6',
      '-', '1', '2', '3', '+', '00', '0', '.', '=']) {
      expect(find.text(k), findsWidgets, reason: 'key $k missing');
    }
  });

  testWidgets('adds up and shows a live result', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['1', '2', '+', '8']);
    expect(find.text('= 20'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('× and ÷ bind tighter than + and -', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['2', '+', '3', '×', '4']);
    expect(find.text('= 14'), findsOneWidget);
  });

  testWidgets('percent reads as percent of the running total', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['1', '0', '0', '+', '1', '0', '%']);
    expect(find.text('= 110'), findsOneWidget);
  });

  testWidgets('= keeps the answer for further work and stores history',
      (tester) async {
    await pumpCalc(tester);
    await press(tester, ['5', '0', '×', '3', '=']);
    expect(find.text('150'), findsWidgets); // display now holds the answer
    expect(find.textContaining('50×3 = 150'), findsOneWidget); // history
    await press(tester, ['+', '5', '0']); // operator continues from the answer
    expect(find.text('= 200'), findsOneWidget);
  });

  testWidgets('typing a number after = starts a fresh sum', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['1', '2', '+', '8', '=']);
    await press(tester, ['5', '0', '+', '5', '=']);
    // The second sum must be 50+5, not 2050+5 glued onto the first answer.
    expect(find.textContaining('50+5 = 55'), findsOneWidget);
    expect(find.textContaining('2050'), findsNothing);
    expect(find.textContaining('12+8 = 20'), findsOneWidget);
  });

  testWidgets('history survives leaving and re-opening the screen',
      (tester) async {
    await pumpCalc(tester);
    await press(tester, ['7', '×', '6', '=']);
    expect(find.textContaining('7×6 = 42'), findsOneWidget);

    // Navigate away to a different screen, then open the calculator again.
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    await tester.pumpAndSettle();
    await pumpCalc(tester);
    expect(find.textContaining('7×6 = 42'), findsOneWidget);
  });

  testWidgets('bare number + = does not add a junk history line',
      (tester) async {
    await pumpCalc(tester);
    await press(tester, ['1', '5', '0', '=']);
    expect(find.textContaining('150 = 150'), findsNothing);
    expect(find.textContaining('Press'), findsOneWidget); // empty-state hint
  });

  testWidgets('pressing = twice does not duplicate the line', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['2', '+', '2', '=', '=']);
    expect(find.textContaining('2+2 = 4'), findsOneWidget);
  });

  testWidgets('tapping a history line reuses its answer', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['9', '×', '9', '=']);
    await press(tester, ['C', '1', '0', '0', '-']);
    await tester.tap(find.textContaining('9×9 = 81'));
    await tester.pump();
    expect(find.text('100-81'), findsOneWidget); // appended, not replaced
    expect(find.text('= 19'), findsOneWidget);
  });

  testWidgets('clear-history button empties the tape', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['4', '+', '4', '=']);
    expect(find.textContaining('4+4 = 8'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.history_toggle_off));
    await tester.pump();
    expect(find.textContaining('4+4 = 8'), findsNothing);
    expect(find.textContaining('Press'), findsOneWidget);
  });

  testWidgets('C clears, backspace removes one character', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['1', '2', '3', '⌫']);
    expect(find.text('12'), findsOneWidget);
    await press(tester, ['C']);
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('decimals and 00 key work', (tester) async {
    await pumpCalc(tester);
    await press(tester, ['1', '.', '5', '×', '2', '00']);
    expect(find.text('= 300'), findsOneWidget);
  });

  testWidgets('divide by zero shows Error instead of crashing',
      (tester) async {
    await pumpCalc(tester);
    await press(tester, ['5', '÷', '0']);
    expect(find.text('= Error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trailing operator does not break the live result',
      (tester) async {
    await pumpCalc(tester);
    await press(tester, ['9', '+']);
    expect(find.text('= 9'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
