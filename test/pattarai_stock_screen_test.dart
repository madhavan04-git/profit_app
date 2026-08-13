import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/screens/pattarai_stock_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PattaraiStockScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('screen renders without a key or Firebase', (tester) async {
    await pump(tester);
    expect(find.text('Sheet / Wastage'), findsOneWidget);
    expect(find.text('Send sheet'), findsOneWidget);
    expect(find.text('Pieces back'), findsOneWidget);
    expect(find.text('Wastage'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the add-pattarai dialog opens and closes without crashing',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.store_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Pattarais'), findsOneWidget);

    await tester.tap(find.text('Add pattarai'));
    await tester.pumpAndSettle();
    expect(find.text('New pattarai'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Pattarai 1');
    await tester.tap(find.text('Save'));

    // The dialog's exit animation rebuilds the text field. Previously a
    // TextEditingController was disposed as soon as showDialog() returned,
    // which blew up right here with "used after being disposed".
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling the dialog is also clean', (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.store_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add pattarai'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'typed then cancelled');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('New pattarai'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty name is rejected instead of saving a blank pattarai',
      (tester) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.store_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add pattarai'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save')); // nothing typed
    await tester.pumpAndSettle();

    // No "added" or error snackbar — the flow simply stops.
    expect(find.textContaining('added'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry sheets are reachable and do not crash', (tester) async {
    await pump(tester);

    // With no pattarais it must tell the owner, not throw.
    await tester.tap(find.text('Send sheet'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Create a pattarai first'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
