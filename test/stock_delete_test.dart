import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/models/models.dart';

RawMaterialTransaction rawTx(
  String type,
  double kg, {
  String? supplierId,
  RawMaterialType material = RawMaterialType.ssSheet,
}) =>
    RawMaterialTransaction(
      materialType: material,
      date: DateTime(2026, 8, 12),
      quantityKg: kg,
      ratePerKg: 220,
      transactionType: type,
      supplierId: supplierId,
      supplierName: supplierId == null ? null : 'Kumar Stores',
    );

void main() {
  group('which rows move company stock', () {
    test('company rows count, party rows do not', () {
      expect(affectsCompanyStock(rawTx('purchase', 100)), isTrue);
      expect(
          affectsCompanyStock(rawTx('purchase', 100, supplierId: 'p1')), isFalse);
    });

    test('an empty supplier id is treated as company, not as a party', () {
      expect(affectsCompanyStock(rawTx('purchase', 100, supplierId: '')), isTrue);
    });
  });

  group('company stock direction', () {
    test('a purchase adds', () {
      expect(companyStockDelta(rawTx('purchase', 100)), 100);
    });

    test('a sale subtracts', () {
      expect(companyStockDelta(rawTx('sale', 40)), -40);
    });

    test('consumption subtracts, whichever sign it was stored with', () {
      expect(companyStockDelta(rawTx('consumption', 30)), -30);
      expect(companyStockDelta(rawTx('consumption', -30)), -30);
    });

    test('wastage subtracts — scrap is no longer usable sheet', () {
      expect(companyStockDelta(rawTx('wastage', 20)), -20);
    });

    test('an unknown type subtracts, so it can never inflate stock', () {
      expect(companyStockDelta(rawTx('something-new', 15)), -15);
    });

    test('a party row moves company stock by nothing', () {
      expect(companyStockDelta(rawTx('purchase', 100, supplierId: 'p1')), 0);
      expect(companyStockDelta(rawTx('sale', 100, supplierId: 'p1')), 0);
    });
  });

  group('undoing a party row', () {
    test('deleting a purchase takes the credited sheet back', () {
      expect(partyStockReversalKg(rawTx('purchase', 120, supplierId: 'p1')),
          -120);
    });

    test('deleting anything else gives the sheet back to the party', () {
      expect(partyStockReversalKg(rawTx('sale', 40, supplierId: 'p1')), 40);
    });

    test('a stray negative quantity cannot flip the direction', () {
      expect(
          partyStockReversalKg(rawTx('purchase', -120, supplierId: 'p1')), -120);
    });

    test('add then delete returns the party balance to where it started', () {
      const opening = 35.0;
      final tx = rawTx('purchase', 120, supplierId: 'p1');
      final afterAdd = opening + tx.quantityKg.abs(); // what saving did
      final afterDelete = afterAdd + partyStockReversalKg(tx);
      expect(afterAdd, 155);
      expect(afterDelete, opening);
    });
  });

  group('the exact mistake: 200 kg entered on the wrong party', () {
    // Party purchases show up in the Inventory total through the party's
    // balance, so deleting one has to come off BOTH.
    PartyStock party(double kg) => PartyStock(
          partyId: 'p1',
          partyName: 'Party 1',
          partyType: 'supplier',
          stock: kg == 0
              ? {}
              : {RawMaterialType.ssSheet: kg},
        );

    final company = {RawMaterialType.ssSheet: 500.0};

    test('before the mistake the total is company stock alone', () {
      expect(combineTotalStock(company, [party(0)])[RawMaterialType.ssSheet],
          500);
    });

    test('the wrong 200 kg entry inflates the total', () {
      expect(combineTotalStock(company, [party(200)])[RawMaterialType.ssSheet],
          700);
    });

    test('deleting it removes the 200 from the total AND from the party', () {
      final tx = rawTx('purchase', 200, supplierId: 'p1');

      // Reversal applied to the party balance...
      final partyAfter = 200 + partyStockReversalKg(tx);
      expect(partyAfter, 0);

      // ...which drops the displayed total straight back to 500.
      final totalAfter =
          combineTotalStock(company, [party(partyAfter)])[RawMaterialType.ssSheet];
      expect(totalAfter, 500);

      // Company stock never counted the party row, so it is untouched.
      expect(companyStockDelta(tx), 0);
    });

    test('a party with other genuine sheet keeps it', () {
      final tx = rawTx('purchase', 200, supplierId: 'p1');
      final partyAfter = 500 + partyStockReversalKg(tx); // 500 real + 200 wrong
      expect(partyAfter, 300);
      expect(
          combineTotalStock(company, [party(partyAfter)])[RawMaterialType.ssSheet],
          800);
    });

    test('a negative party balance is not subtracted from the total again', () {
      // The shortfall already came out of company stock at sale time.
      expect(combineTotalStock(company, [party(-150)])[RawMaterialType.ssSheet],
          500);
    });

    test('several parties add up', () {
      final p2 = PartyStock(
        partyId: 'p2',
        partyName: 'Party 2',
        partyType: 'buyer',
        stock: {RawMaterialType.ssSheet: 75, RawMaterialType.brassSheet: 20},
      );
      final total = combineTotalStock(company, [party(200), p2]);
      expect(total[RawMaterialType.ssSheet], 775);
      expect(total[RawMaterialType.brassSheet], 20);
    });

    test('combining does not mutate the company map it was given', () {
      final original = {RawMaterialType.ssSheet: 500.0};
      combineTotalStock(original, [party(200)]);
      expect(original[RawMaterialType.ssSheet], 500);
    });
  });

  group('company stock rebuilds correctly after a delete', () {
    // getCurrentStock() re-sums every remaining row, so deleting one simply
    // removes its delta. This proves the arithmetic behind that.
    double total(List<RawMaterialTransaction> txs) =>
        txs.fold(0.0, (s, t) => s + companyStockDelta(t));

    test('a purchase, a sale and a wastage net out', () {
      final txs = [
        rawTx('purchase', 500),
        rawTx('sale', 120),
        rawTx('wastage', 20),
      ];
      expect(total(txs), 360);

      // Delete the wastage → the 20 kg comes back.
      final without = [...txs]..removeWhere((t) => t.transactionType == 'wastage');
      expect(total(without), 380);
    });

    test('deleting a party purchase leaves company stock untouched', () {
      final txs = [
        rawTx('purchase', 500),
        rawTx('purchase', 200, supplierId: 'p1'),
      ];
      expect(total(txs), 500);
      final without = [...txs]..removeWhere((t) => t.supplierId != null);
      expect(total(without), 500);
    });
  });
}
