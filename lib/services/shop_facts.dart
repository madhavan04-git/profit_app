// lib/services/shop_facts.dart
// One read of the shop's numbers, shared by the offline answer engine and by
// the text snapshot sent to the AI. Fetched once, used by both.
import 'package:intl/intl.dart';

import '../models/models.dart';
import 'firebase_service.dart';

final _rsFmt = NumberFormat('#,##0', 'en_IN');

String rs(num v) => 'Rs ${_rsFmt.format(v.round())}';
String kgs(num v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} kg';

/// A named amount — product, buyer, expense head, worker role, material.
class NamedAmount {
  final String name;
  final double value;
  const NamedAmount(this.name, this.value);
}

class ShopFacts {
  final DateTime asOf;
  final List<String> shopNames;

  final int todaySales;
  final double todayRevenue;
  final double todayProfit;

  final int monthSales;
  final double monthKg;
  final double monthRevenue;
  final double monthProfit;
  final double monthExpenses;
  final double monthNetProfit;
  final double monthWages;
  final double lastMonthProfit;

  final List<NamedAmount> profitByProduct;
  final List<NamedAmount> profitByCategory;
  final List<NamedAmount> profitByBuyer;
  final List<NamedAmount> expensesByHead;
  final List<NamedAmount> wagesByRole;
  final List<NamedAmount> pendingByBuyer; // positive = they still owe us
  final List<NamedAmount> stock;

  final List<Product> products;
  final List<Worker> workers;
  final bool partial; // true when something failed to load

  const ShopFacts({
    required this.asOf,
    required this.shopNames,
    required this.todaySales,
    required this.todayRevenue,
    required this.todayProfit,
    required this.monthSales,
    required this.monthKg,
    required this.monthRevenue,
    required this.monthProfit,
    required this.monthExpenses,
    required this.monthNetProfit,
    required this.monthWages,
    required this.lastMonthProfit,
    required this.profitByProduct,
    required this.profitByCategory,
    required this.profitByBuyer,
    required this.expensesByHead,
    required this.wagesByRole,
    required this.pendingByBuyer,
    required this.stock,
    required this.products,
    required this.workers,
    this.partial = false,
  });

  double get totalPending =>
      pendingByBuyer.fold(0.0, (s, e) => s + (e.value > 0 ? e.value : 0));

  double get profitChange => monthProfit - lastMonthProfit;

  static ShopFacts empty() => ShopFacts(
        asOf: DateTime.now(),
        shopNames: const [],
        todaySales: 0,
        todayRevenue: 0,
        todayProfit: 0,
        monthSales: 0,
        monthKg: 0,
        monthRevenue: 0,
        monthProfit: 0,
        monthExpenses: 0,
        monthNetProfit: 0,
        monthWages: 0,
        lastMonthProfit: 0,
        profitByProduct: const [],
        profitByCategory: const [],
        profitByBuyer: const [],
        expensesByHead: const [],
        wagesByRole: const [],
        pendingByBuyer: const [],
        stock: const [],
        products: const [],
        workers: const [],
        partial: true,
      );

  /// Reads everything the assistant needs in one parallel batch.
  static Future<ShopFacts> load() async {
    final svc = FirebaseService.instance;
    final now = DateTime.now();
    final prev = DateTime(now.year, now.month - 1);

    try {
      final r = await Future.wait([
        svc.monthlySummary(now.year, now.month),
        svc.salesForDate(now),
        svc.monthlyTotalProfit(prev.year, prev.month),
        svc.getProducts(),
        svc.getBuyers(),
        svc.getWorkers(),
        svc.getTotalStock(),
        svc.getPattarais(),
        svc.allBuyerSimpleTransactionsStream().first,
        svc.getAllSales(),
      ]);

      final m = r[0] as MonthlySummary;
      final today = r[1] as List<Sale>;
      final lastProfit = r[2] as double;
      final products = r[3] as List<Product>;
      final buyers = r[4] as List<Buyer>;
      final workers = r[5] as List<Worker>;
      final stock = r[6] as Map<RawMaterialType, double>;
      final pattarais = r[7] as List<Pattarai>;
      final buyerTx = r[8] as List<SimpleTransaction>;
      final allSales = r[9] as List<Sale>;

      List<NamedAmount> sorted(Map<String, double> m) =>
          (m.entries.map((e) => NamedAmount(e.key, e.value)).toList()
            ..sort((a, b) => b.value.compareTo(a.value)));

      // Pending = all-time sales value + manual credits - payments, the same
      // rule the Buyer Tx screen uses.
      final owed = <String, double>{};
      for (final s in allSales) {
        final id = s.buyerId;
        if (id != null && id.isNotEmpty) {
          owed[id] = (owed[id] ?? 0) + s.qty * s.salePrice;
        }
      }
      for (final t in buyerTx) {
        if (t.buyerId.isEmpty) continue;
        owed[t.buyerId] = (owed[t.buyerId] ?? 0) +
            (t.type == SimpleTxType.credit ? t.amount : -t.amount);
      }
      final pending = <NamedAmount>[];
      for (final b in buyers) {
        final v = owed[b.id] ?? 0;
        if (v.abs() >= 1) pending.add(NamedAmount(b.name, v));
      }
      pending.sort((a, b) => b.value.compareTo(a.value));

      return ShopFacts(
        asOf: now,
        shopNames: pattarais.map((p) => p.name).toList(),
        todaySales: today.length,
        todayRevenue: today.fold(0.0, (s, x) => s + x.qty * x.salePrice),
        todayProfit: today.fold(0.0, (s, x) => s + x.profit),
        monthSales: m.sales.length,
        monthKg: m.totalKg,
        monthRevenue: m.totalRevenue,
        monthProfit: m.totalProfit,
        monthExpenses: m.totalExpenses,
        monthNetProfit: m.netProfit,
        monthWages: m.autoWageTotal + m.attendanceWages,
        lastMonthProfit: lastProfit,
        profitByProduct: sorted(m.productMap)
            .map((e) => NamedAmount(e.name.split('|').last, e.value))
            .toList(),
        profitByCategory: sorted(m.profitByCategory),
        profitByBuyer: m.buyerList
            .map((b) => NamedAmount(b.buyerName, b.totalProfit))
            .toList(),
        expensesByHead: sorted(m.expenseCatMap),
        wagesByRole: sorted(m.workerWageByRole),
        pendingByBuyer: pending,
        stock: stock.entries
            .where((e) => e.value.abs() >= 0.01)
            .map((e) => NamedAmount(e.key.displayName, e.value))
            .toList(),
        products: products,
        workers: workers,
      );
    } catch (_) {
      return ShopFacts.empty();
    }
  }

  /// Compact text handed to the AI as context. Deliberately terse — every
  /// extra line is tokens spent out of a free daily quota.
  String toPromptText() {
    final b = StringBuffer();
    b.writeln('Date: ${asOf.toIso8601String().substring(0, 10)}');
    if (shopNames.isNotEmpty) b.writeln('Shop: ${shopNames.join(', ')}');

    b.writeln('\nTODAY: $todaySales sales, revenue ${rs(todayRevenue)}, '
        'profit ${rs(todayProfit)}');

    b.writeln('\nTHIS MONTH: $monthSales sales, ${kgs(monthKg)}, '
        'revenue ${rs(monthRevenue)}, gross profit ${rs(monthProfit)}, '
        'expenses ${rs(monthExpenses)}, net ${rs(monthNetProfit)}, '
        'worker wages ${rs(monthWages)}');
    b.writeln('LAST MONTH gross profit: ${rs(lastMonthProfit)}');

    // Pre-computed so the model never has to work these out itself.
    final daysDone = asOf.day;
    final daysInMonth = DateTime(asOf.year, asOf.month + 1, 0).day;
    if (daysDone > 0) {
      final perDay = monthProfit / daysDone;
      b.writeln('Day $daysDone of $daysInMonth. '
          'Average gross profit per day so far: ${rs(perDay)}. '
          'At this rate the month ends near ${rs(perDay * daysInMonth)}.');
    }
    final change = monthProfit - lastMonthProfit;
    b.writeln('Change vs last month: ${change >= 0 ? '+' : '-'}'
        '${rs(change.abs())}'
        '${lastMonthProfit > 0 ? ' (${(change / lastMonthProfit * 100).toStringAsFixed(1)}%)' : ''}');
    if (monthRevenue > 0) {
      b.writeln('Profit margin this month: '
          '${(monthProfit / monthRevenue * 100).toStringAsFixed(1)}% of revenue.');
    }

    void list(String title, List<NamedAmount> items, {int take = 6, bool money = true}) {
      if (items.isEmpty) return;
      b.writeln('\n$title:');
      for (final e in items.take(take)) {
        b.writeln('- ${e.name}: ${money ? rs(e.value) : kgs(e.value)}');
      }
    }

    list('PROFIT BY PRODUCT (month, best first)', profitByProduct);
    list('PROFIT BY CATEGORY (month)', profitByCategory);
    list('TOP BUYERS BY PROFIT (month)', profitByBuyer, take: 5);
    list('EXPENSES (month)', expensesByHead);
    list('WORKER EARNINGS BY ROLE (month)', wagesByRole);
    list('BUYER PENDING (all time, + = they owe us)', pendingByBuyer, take: 8);
    list('RAW MATERIAL STOCK', stock, money: false);

    if (products.isNotEmpty) {
      b.writeln('\nPRODUCT RATES (up to 15):');
      for (final p in products.take(15)) {
        b.writeln('- ${p.name} (${p.category}) ${p.productWeightG}g/pc, '
            'sell ${rs(p.sellPricePerKg)}/kg, cost ${rs(p.costPerKg)}/kg, '
            'profit ${rs(p.profitPerKg)}/kg');
      }
    }
    if (partial) b.writeln('\n(NOTE: some records could not be read.)');
    return b.toString();
  }
}
