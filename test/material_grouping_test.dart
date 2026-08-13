import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/models/models.dart';

void main() {
  group('metal grouping', () {
    test('every raw material maps to the right metal', () {
      expect(RawMaterialType.ssSheet.metal, MaterialMetal.ss);
      expect(RawMaterialType.ssCircle.metal, MaterialMetal.ss);
      expect(RawMaterialType.brassSheet.metal, MaterialMetal.brass);
      expect(RawMaterialType.brassCircle.metal, MaterialMetal.brass);
      expect(RawMaterialType.copperSheet.metal, MaterialMetal.copper);
      expect(RawMaterialType.copperCircle.metal, MaterialMetal.copper);
    });

    test('metal + form resolves back to the stored type', () {
      for (final m in MaterialMetal.values) {
        expect(m.form(isSheet: true), m.sheet);
        expect(m.form(isSheet: false), m.circle);
        expect(m.sheet.isSheet, isTrue);
        expect(m.circle.isCircle, isTrue);
        expect(m.sheet.metal, m);
        expect(m.circle.metal, m);
      }
    });

    test('the six types are exactly 3 metals x 2 forms', () {
      final built = <RawMaterialType>{
        for (final m in MaterialMetal.values) ...[m.sheet, m.circle]
      };
      expect(built, RawMaterialType.values.toSet());
    });

    test('display names are unchanged, so stored records still parse', () {
      // Firestore holds these strings — renaming them would orphan old rows.
      expect(MaterialMetal.ss.sheet.displayName, 'SS Sheet');
      expect(MaterialMetal.ss.circle.displayName, 'SS Circle');
      expect(RawMaterialType.fromString('SS Circle'), RawMaterialType.ssCircle);
      expect(RawMaterialType.fromString('Brass Sheet'),
          RawMaterialType.brassSheet);
    });

    test('chip labels are the upper-case metal names', () {
      expect(MaterialMetal.ss.chipLabel, 'SS');
      expect(MaterialMetal.brass.chipLabel, 'BRASS');
      expect(MaterialMetal.copper.chipLabel, 'COPPER');
    });
  });

  group('stock totals per metal', () {
    final stock = {
      RawMaterialType.ssSheet: 80.0,
      RawMaterialType.ssCircle: 40.5,
      RawMaterialType.brassSheet: 12.0,
      RawMaterialType.copperCircle: -3.0,
    };

    double totalFor(MaterialMetal m) =>
        (stock[m.sheet] ?? 0) + (stock[m.circle] ?? 0);

    test('SS adds sheet and circle together', () {
      expect(totalFor(MaterialMetal.ss), 120.5);
    });

    test('a missing form counts as zero, not an error', () {
      expect(totalFor(MaterialMetal.brass), 12.0);
    });

    test('a negative balance carries through as a deficit', () {
      expect(totalFor(MaterialMetal.copper), -3.0);
    });
  });
}
