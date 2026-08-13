import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/services/app_toast.dart';

void main() {
  setUp(AppToast.resetRotation);

  group('messages rotate instead of repeating', () {
    test('three sales in a row give three different lines', () {
      final seen = [
        AppToast.message(ToastEvent.sale, name: 'Kumar'),
        AppToast.message(ToastEvent.sale, name: 'Kumar'),
        AppToast.message(ToastEvent.sale, name: 'Kumar'),
      ];
      expect(seen.toSet().length, 3);
    });

    test('each event has its own rotation', () {
      final sale1 = AppToast.message(ToastEvent.sale);
      AppToast.message(ToastEvent.payment);
      AppToast.message(ToastEvent.payment);
      final sale2 = AppToast.message(ToastEvent.sale);
      expect(sale1, isNot(sale2)); // payments did not advance the sale list
    });

    test('the list wraps around and keeps working', () {
      final lines = <String>{};
      for (var i = 0; i < 40; i++) {
        lines.add(AppToast.message(ToastEvent.sale, name: 'Kumar'));
      }
      expect(lines.length, greaterThan(3));
      expect(lines.every((l) => l.trim().isNotEmpty), isTrue);
    });
  });

  group('names', () {
    test('the name is ALWAYS used when there is one', () {
      // Not "sometimes" — a nameless line must never appear when we know who
      // the sale was to.
      for (final e in ToastEvent.values) {
        for (var i = 0; i < 8; i++) {
          expect(AppToast.message(e, name: 'Kumar'), contains('Kumar'),
              reason: '$e dropped the name');
        }
      }
    });

    test('any real buyer name works — nothing is hardcoded', () {
      const buyers = [
        'Ravi',
        'Lakshmi Traders',
        'Sri Murugan Steels',
        'முருகன்',
        'A',
        "D'Souza",
      ];
      for (final buyer in buyers) {
        AppToast.resetRotation();
        final m = AppToast.message(ToastEvent.sale, name: buyer);
        final firstWord = buyer.split(' ').first;
        expect(m, contains(firstWord), reason: 'lost the name for "$buyer"');
        expect(m, isNot(contains('Kumar')));
      }
    });

    test('the same event with different buyers shows different names', () {
      final a = AppToast.message(ToastEvent.payment, name: 'Ravi');
      final b = AppToast.message(ToastEvent.payment, name: 'Lakshmi');
      expect(a, contains('Ravi'));
      expect(b, contains('Lakshmi'));
      expect(a, isNot(contains('Lakshmi')));
      expect(b, isNot(contains('Ravi')));
    });

    test('named lines still rotate', () {
      final seen = {
        for (var i = 0; i < 6; i++)
          AppToast.message(ToastEvent.sale, name: 'Kumar')
      };
      expect(seen.length, greaterThan(3));
      expect(seen.every((l) => l.contains('Kumar')), isTrue);
    });

    test('no placeholder ever leaks through', () {
      for (final e in ToastEvent.values) {
        for (var i = 0; i < 8; i++) {
          expect(AppToast.message(e, name: 'Kumar'), isNot(contains('{name}')));
          expect(AppToast.message(e), isNot(contains('{name}')));
        }
      }
    });

    test('without a name only nameless lines are used', () {
      for (var i = 0; i < 10; i++) {
        final m = AppToast.message(ToastEvent.payment);
        expect(m, isNot(contains('{name}')));
        expect(m.trim(), isNotEmpty);
      }
    });

    test('an empty or blank name counts as no name', () {
      expect(AppToast.message(ToastEvent.sale, name: '   '),
          isNot(contains('{name}')));
      expect(AppToast.message(ToastEvent.sale, name: ''),
          isNot(contains('{name}')));
    });

    test('only the first name is used, so the toast stays on one line', () {
      final lines = [
        for (var i = 0; i < 6; i++)
          AppToast.message(ToastEvent.sale, name: 'Kumar Stores Metal Works')
      ];
      final withName = lines.firstWhere((l) => l.contains('Kumar'));
      expect(withName, isNot(contains('Stores')));
    });

    test('a very long single name is trimmed', () {
      final lines = [
        for (var i = 0; i < 6; i++)
          AppToast.message(ToastEvent.sale,
              name: 'Venkataramanujachariar')
      ];
      expect(lines.every((l) => l.length < 60), isTrue);
    });
  });

  group('every event produces a short English line', () {
    test('nothing is empty and nothing is long', () {
      for (final e in ToastEvent.values) {
        for (var i = 0; i < 6; i++) {
          final m = AppToast.message(e, name: 'Kumar');
          expect(m.trim(), isNotEmpty, reason: '$e produced an empty toast');
          expect(m.length, lessThanOrEqualTo(45),
              reason: '$e produced a long toast: "$m"');
        }
      }
    });

    test('no Tamil script — toasts are English only', () {
      final tamil = RegExp(r'[஀-௿]');
      for (final e in ToastEvent.values) {
        for (var i = 0; i < 6; i++) {
          expect(tamil.hasMatch(AppToast.message(e, name: 'Kumar')), isFalse);
        }
      }
    });
  });
}
