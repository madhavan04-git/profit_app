import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/screens/weight_split_screen.dart';

int sumG(List<SplitLine> lines) => lines.fold(0, (s, l) => s + l.totalG);

void main() {
  group('distributeWeight', () {
    test('in-range total: exact sum, every avg inside its band', () {
      final items = [
        const SplitItem(name: 'A', pieces: 200, minG: 400, maxG: 420),
        const SplitItem(name: 'B', pieces: 55, minG: 300, maxG: 310),
        const SplitItem(name: 'C', pieces: 40, minG: 200, maxG: 220),
      ];
      const total = 106000; // min = 104500, max = 109050
      final r = distributeWeight(totalG: total, items: items);
      expect(sumG(r), total);
      for (var i = 0; i < r.length; i++) {
        expect(r[i].avgG, greaterThanOrEqualTo(items[i].minG - 0.01));
        expect(r[i].avgG, lessThanOrEqualTo(items[i].maxG + 0.01));
        expect(r[i].outOfRange, isFalse);
      }
      // Not a flat proportional fill — the lines sit at different fill levels.
      final fill = [
        for (var i = 0; i < r.length; i++)
          (r[i].avgG - items[i].minG) / (items[i].maxG - items[i].minG)
      ];
      expect((fill.reduce((a, b) => a > b ? a : b) -
              fill.reduce((a, b) => a < b ? a : b))
          .abs(),
          greaterThan(0.05));
    });

    test('user example (total above the realistic max) still sums exactly', () {
      final items = [
        const SplitItem(name: 'Product A', pieces: 200, minG: 400, maxG: 420),
        const SplitItem(name: 'Product B', pieces: 55, minG: 300, maxG: 315),
        const SplitItem(name: 'Product C', pieces: 0, minG: 200, maxG: 220),
      ];
      final r = distributeWeight(totalG: 103300, items: items);
      expect(sumG(r), 103300);
      expect(r.last.totalG, 0); // zero pieces -> zero weight
      expect(r.first.avgG, greaterThan(400));
    });

    test('total below the approx minimum still sums exactly', () {
      final items = [
        const SplitItem(name: 'A', pieces: 100, minG: 400, maxG: 420),
        const SplitItem(name: 'B', pieces: 50, minG: 300, maxG: 310),
      ];
      final r = distributeWeight(totalG: 50000, items: items); // min = 55000
      expect(sumG(r), 50000);
    });

    test('exact sum holds across many random-ish totals and salts', () {
      final items = [
        const SplitItem(name: 'Kadai', pieces: 137, minG: 400, maxG: 420),
        const SplitItem(name: 'Thattu', pieces: 63, minG: 300, maxG: 310),
        const SplitItem(name: 'Tumbler', pieces: 211, minG: 200, maxG: 220),
        const SplitItem(name: 'Chombu', pieces: 7, minG: 150, maxG: 158),
      ];
      for (var t = 100000; t <= 160000; t += 137) {
        for (var salt = 0; salt < 3; salt++) {
          final r = distributeWeight(totalG: t, items: items, salt: salt);
          expect(sumG(r), t, reason: 'total=$t salt=$salt');
        }
      }
    });

    test('different salt gives a different but still exact split', () {
      final items = [
        const SplitItem(name: 'A', pieces: 200, minG: 400, maxG: 420),
        const SplitItem(name: 'B', pieces: 55, minG: 300, maxG: 310),
      ];
      final a = distributeWeight(totalG: 98000, items: items, salt: 0);
      final b = distributeWeight(totalG: 98000, items: items, salt: 5);
      expect(sumG(a), 98000);
      expect(sumG(b), 98000);
      expect(a.first.totalG == b.first.totalG, isFalse);
    });

    test('single product absorbs everything exactly', () {
      final r = distributeWeight(
        totalG: 41234,
        items: [const SplitItem(name: 'Only', pieces: 100, minG: 400, maxG: 420)],
      );
      expect(sumG(r), 41234);
      expect(r.first.avgG, closeTo(412.34, 0.001));
    });

    test('no pieces at all -> all zero, no crash', () {
      final r = distributeWeight(
        totalG: 5000,
        items: [const SplitItem(name: 'A', pieces: 0, minG: 400, maxG: 420)],
      );
      expect(sumG(r), 0);
    });
  });
}
