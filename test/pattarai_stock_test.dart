import 'package:flutter_test/flutter_test.dart';
import 'package:profit_tracker/models/models.dart';

PattaraiStockTx tx(
  String pattarai,
  PattaraiTxType type,
  double kg, {
  RawMaterialType material = RawMaterialType.ssSheet,
  int day = 1,
}) =>
    PattaraiStockTx(
      pattaraiId: pattarai,
      pattaraiName: pattarai,
      type: type,
      materialType: material,
      quantityKg: kg,
      date: DateTime(2026, 8, day),
    );

void main() {
  group('the flow the owner described', () {
    test('120 kg out, 100 kg pieces back, 20 kg wastage settles to zero', () {
      final b = computePattaraiBalances([
        tx('Pattarai 1', PattaraiTxType.issue, 120),
        tx('Pattarai 1', PattaraiTxType.pieces, 100, day: 20),
        tx('Pattarai 1', PattaraiTxType.wastage, 20, day: 30),
      ]).single;

      expect(b.issued, 120);
      expect(b.piecesBack, 100);
      expect(b.wastage, 20);
      expect(b.outstanding, 0);
      expect(b.wastagePercent, closeTo(0.1667, 0.0001));
    });

    test('before wastage is settled, the shortfall is still outstanding', () {
      final b = computePattaraiBalances([
        tx('Pattarai 1', PattaraiTxType.issue, 120),
        tx('Pattarai 1', PattaraiTxType.pieces, 100, day: 20),
      ]).single;

      // This 20 kg is what the Settle button offers to record as wastage.
      expect(b.outstanding, 20);
      expect(b.wastage, 0);
    });

    test('two months of issues settled by one bulk wastage entry', () {
      final b = computePattaraiBalances([
        tx('Pattarai 1', PattaraiTxType.issue, 120, day: 2),
        tx('Pattarai 1', PattaraiTxType.pieces, 104, day: 26),
        tx('Pattarai 1', PattaraiTxType.issue, 150, day: 3),
        tx('Pattarai 1', PattaraiTxType.pieces, 129, day: 27),
        // One settlement covering both months.
        tx('Pattarai 1', PattaraiTxType.wastage, 37, day: 28),
      ]).single;

      expect(b.issued, 270);
      expect(b.piecesBack, 233);
      expect(b.outstanding, 0);
    });
  });

  group('several pattarais stay separate', () {
    final txs = [
      tx('Pattarai 1', PattaraiTxType.issue, 120),
      tx('Pattarai 2', PattaraiTxType.issue, 80),
      tx('Pattarai 1', PattaraiTxType.pieces, 100, day: 20),
      tx('Pattarai 2', PattaraiTxType.pieces, 70, day: 20),
      tx('Pattarai 2', PattaraiTxType.wastage, 10, day: 28),
    ];

    test('each gets its own balance', () {
      final all = computePattaraiBalances(txs);
      expect(all.length, 2);
      final p1 = all.firstWhere((b) => b.pattaraiName == 'Pattarai 1');
      final p2 = all.firstWhere((b) => b.pattaraiName == 'Pattarai 2');
      expect(p1.outstanding, 20); // not settled yet
      expect(p2.outstanding, 0); // settled
    });

    test('sorted with the biggest pending first', () {
      expect(computePattaraiBalances(txs).first.pattaraiName, 'Pattarai 1');
    });
  });

  group('metals do not mix', () {
    final txs = [
      tx('Pattarai 1', PattaraiTxType.issue, 120),
      tx('Pattarai 1', PattaraiTxType.issue, 50,
          material: RawMaterialType.brassSheet),
      tx('Pattarai 1', PattaraiTxType.pieces, 100, day: 20),
    ];

    test('filtering by SS ignores the brass entry', () {
      final ss =
          computePattaraiBalances(txs, metal: MaterialMetal.ss).single;
      expect(ss.issued, 120);
      expect(ss.outstanding, 20);
    });

    test('filtering by Brass ignores the SS entries', () {
      final brass =
          computePattaraiBalances(txs, metal: MaterialMetal.brass).single;
      expect(brass.issued, 50);
      expect(brass.piecesBack, 0);
      expect(brass.outstanding, 50);
    });

    test('with no filter everything is summed together', () {
      expect(computePattaraiBalances(txs).single.issued, 170);
    });
  });

  group('edge cases', () {
    test('no entries gives no balances', () {
      expect(computePattaraiBalances([]), isEmpty);
    });

    test('more pieces back than sent shows a negative — a data entry mistake',
        () {
      final b = computePattaraiBalances([
        tx('Pattarai 1', PattaraiTxType.issue, 100),
        tx('Pattarai 1', PattaraiTxType.pieces, 130, day: 20),
      ]).single;
      expect(b.outstanding, -30);
    });

    test('wastage percent is null until something is issued', () {
      final b = computePattaraiBalances([
        tx('Pattarai 1', PattaraiTxType.wastage, 5),
      ]).single;
      expect(b.wastagePercent, isNull);
      expect(b.outstanding, -5);
    });

    test('quantities are treated as magnitudes, so a stray minus cannot flip '
        'an issue into a deduction', () {
      final b = computePattaraiBalances([
        tx('Pattarai 1', PattaraiTxType.issue, -120),
      ]).single;
      expect(b.issued, 120);
    });
  });

  group('wastage store — scrap kept back and sold every few months', () {
    WastageSale sale(double kg, double rate,
            {RawMaterialType material = RawMaterialType.ssSheet}) =>
        WastageSale(
          materialType: material,
          quantityKg: kg,
          ratePerKg: rate,
          date: DateTime(2026, 8, 30),
        );

    test('recorded wastage piles up until it is sold', () {
      final txs = [
        tx('Pattarai 1', PattaraiTxType.wastage, 20),
        tx('Pattarai 2', PattaraiTxType.wastage, 15),
      ];
      expect(wastageInStore(txs, []), 35);
    });

    test('selling clears it out of the store', () {
      final txs = [
        tx('Pattarai 1', PattaraiTxType.wastage, 20),
        tx('Pattarai 2', PattaraiTxType.wastage, 15),
      ];
      expect(wastageInStore(txs, [sale(30, 60)]), 5);
    });

    test('six months of wastage sold in one go leaves nothing', () {
      final txs = [
        for (var i = 1; i <= 6; i++)
          tx('Pattarai 1', PattaraiTxType.wastage, 20, day: i),
      ];
      expect(wastageInStore(txs, [sale(120, 55)]), 0);
    });

    test('issues and pieces are not scrap', () {
      final txs = [
        tx('Pattarai 1', PattaraiTxType.issue, 120),
        tx('Pattarai 1', PattaraiTxType.pieces, 100),
        tx('Pattarai 1', PattaraiTxType.wastage, 20),
      ];
      expect(wastageInStore(txs, []), 20);
    });

    test('each metal keeps its own scrap pile', () {
      final txs = [
        tx('Pattarai 1', PattaraiTxType.wastage, 20),
        tx('Pattarai 1', PattaraiTxType.wastage, 8,
            material: RawMaterialType.brassSheet),
      ];
      final sales = [sale(5, 60)]; // SS only
      expect(wastageInStore(txs, sales, metal: MaterialMetal.ss), 15);
      expect(wastageInStore(txs, sales, metal: MaterialMetal.brass), 8);
      expect(wastageInStore(txs, sales), 23);
    });

    test('selling more than recorded shows a negative, not a silent zero', () {
      final txs = [tx('Pattarai 1', PattaraiTxType.wastage, 10)];
      expect(wastageInStore(txs, [sale(14, 60)]), -4);
    });

    test('income adds up, per metal and overall', () {
      final sales = [
        sale(100, 55),
        sale(40, 300, material: RawMaterialType.brassSheet),
      ];
      expect(wastageSaleIncome(sales, metal: MaterialMetal.ss), 5500);
      expect(wastageSaleIncome(sales, metal: MaterialMetal.brass), 12000);
      expect(wastageSaleIncome(sales), 17500);
    });

    test('a sale survives storage round-trip', () {
      final original = WastageSale(
        materialType: RawMaterialType.ssSheet,
        quantityKg: 118.5,
        ratePerKg: 52.5,
        date: DateTime(2026, 8, 30),
        buyerName: 'Scrap Mart',
        note: 'Mar to Aug collection',
      );
      final back = WastageSale.fromMap('w1', original.toMap());
      expect(back.quantityKg, 118.5);
      expect(back.ratePerKg, 52.5);
      expect(back.buyerName, 'Scrap Mart');
      expect(back.amount, closeTo(6221.25, 0.001));
      expect(original.toMap()['amount'], closeTo(6221.25, 0.001));
    });
  });

  group('storage round-trip', () {
    test('an entry survives being written and read back', () {
      final original = PattaraiStockTx(
        pattaraiId: 'abc123',
        pattaraiName: 'Sri Murugan Pattarai',
        type: PattaraiTxType.wastage,
        materialType: RawMaterialType.brassSheet,
        quantityKg: 18.5,
        date: DateTime(2026, 8, 30),
        note: 'Aug + Sep settlement',
        stockTxId: 'raw_tx_1',
      );
      final back = PattaraiStockTx.fromMap('id1', original.toMap());

      expect(back.pattaraiId, 'abc123');
      expect(back.pattaraiName, 'Sri Murugan Pattarai');
      expect(back.type, PattaraiTxType.wastage);
      expect(back.materialType, RawMaterialType.brassSheet);
      expect(back.quantityKg, 18.5);
      expect(back.date, DateTime(2026, 8, 30));
      expect(back.note, 'Aug + Sep settlement');
      expect(back.stockTxId, 'raw_tx_1');
    });

    test('only wastage carries a company-stock link', () {
      final issue = PattaraiStockTx(
        pattaraiId: 'a',
        pattaraiName: 'A',
        type: PattaraiTxType.issue,
        materialType: RawMaterialType.ssSheet,
        quantityKg: 10,
        date: DateTime(2026, 8, 1),
      );
      expect(issue.toMap().containsKey('stockTxId'), isFalse);
    });

    test('signed kg follows the accounting rule', () {
      expect(tx('A', PattaraiTxType.issue, 10).signedKg, 10);
      expect(tx('A', PattaraiTxType.pieces, 10).signedKg, -10);
      expect(tx('A', PattaraiTxType.wastage, 10).signedKg, -10);
    });
  });
}
