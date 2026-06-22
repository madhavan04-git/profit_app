// lib/screens/monthly_screen.dart
// Full monthly report with Yearly & Overall Profit + Category breakdown

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/firebase_service.dart';
import 'pdf_service.dart';
import '../models/models.dart';

class MonthlyScreen extends StatefulWidget {
  const MonthlyScreen({super.key});
  @override State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen>
    with SingleTickerProviderStateMixin {
  final _svc = FirebaseService.instance;
  late TabController _tabs;

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  MonthlySummary? _summary;
  bool _loading = true;
  bool _pdfLoading = false;
  bool _yearView = false;
  Map<int, double> _yearMap = {};

  double _yearProfit = 0;
  double _overallProfit = 0;
  bool _loadingExtra = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await _svc.monthlySummary(_month.year, _month.month);
      final results = await Future.wait([
        _svc.yearlyTotalProfit(_month.year),
        _svc.overallTotalProfit(),
      ]);
      setState(() {
        _summary = summary;
        _yearProfit = results[0];
        _overallProfit = results[1];
        _loading = false;
        _loadingExtra = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadYearView() async {
    setState(() => _yearView = true);
    final Map<int, double> map = {};
    final futures = List.generate(12, (i) =>
        _svc.monthlyTotalProfit(_month.year, i + 1));
    final results = await Future.wait(futures);
    for (int i = 0; i < 12; i++) map[i + 1] = results[i];
    setState(() => _yearMap = map);
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month == now.month) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _load();
  }

  Future<void> _exportPdf() async {
    final s = _summary;
    if (s == null) return;
    setState(() => _pdfLoading = true);
    try {
      await PdfService.generateMonthlyReport(
        month: _month,
        sales: s.sales,
        dailyMap: s.dailyMap,
        productMap: s.productMap,
        totalProfit: s.totalProfit,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF saved & shared'),
              backgroundColor: Color(0xFF1A6B2A)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF error: $e'), backgroundColor: Colors.red));
    }
    setState(() => _pdfLoading = false);
  }

  final _fmt    = NumberFormat('#,##0.00', 'en_IN');
  final _fmtInt = NumberFormat('#,##0',    'en_IN');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Report'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Sales'),
            Tab(text: 'Buyers'),
            Tab(text: 'Workers'),
            Tab(text: 'Expenses'),
            Tab(text: 'Materials'),
            Tab(text: 'Filter', icon: Icon(Icons.filter_alt_outlined, size: 16)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_yearView ? Icons.calendar_month : Icons.calendar_view_month),
            tooltip: _yearView ? 'Month view' : 'Year view',
            onPressed: () {
              if (_yearView) {
                setState(() => _yearView = false);
              } else {
                _loadYearView();
              }
            },
          ),
          if (!_loading && _summary != null)
            IconButton(
              icon: _pdfLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _pdfLoading ? null : _exportPdf,
            ),
        ],
      ),
      body: _yearView
          ? _YearView(
              year: _month.year,
              yearMap: _yearMap,
              onMonthTap: (m) {
                setState(() {
                  _month = DateTime(_month.year, m);
                  _yearView = false;
                });
                _load();
              },
            )
          : Column(children: [
              _MonthSelector(
                month: _month,
                onPrev: _prevMonth,
                onNext: _nextMonth,
                isCurrent: isCurrent,
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_summary == null)
                const Expanded(child: Center(child: Text('No data')))
              else
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _OverviewTab(
                        summary: _summary!,
                        month: _month,
                        fmt: _fmt,
                        fmtInt: _fmtInt,
                        yearProfit: _yearProfit,
                        overallProfit: _overallProfit,
                      ),
                      _SalesTab(summary: _summary!, fmt: _fmt),
                      _BuyersTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _WorkersTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _ExpensesTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _MaterialsTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      const _FilterTab(),
                    ],
                  ),
                ),
            ]),
    );
  }
}

// ── Month selector ───────────────────────────────────────────────────────────
class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;
  final bool isCurrent;
  const _MonthSelector({required this.month, required this.onPrev,
      required this.onNext, required this.isCurrent});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, size: 28, color: Color(0xFF1F4E79))),
      Text(DateFormat('MMMM yyyy').format(month),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
              color: Color(0xFF1F4E79))),
      IconButton(
          onPressed: isCurrent ? null : onNext,
          icon: Icon(Icons.chevron_right, size: 28,
              color: isCurrent ? Colors.grey.shade300 : const Color(0xFF1F4E79))),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — OVERVIEW (UPDATED with Year Profit, Overall Profit & Category breakdown)
// ══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatefulWidget {
  final MonthlySummary summary;
  final DateTime month;
  final NumberFormat fmt, fmtInt;
  final double yearProfit;
  final double overallProfit;

  const _OverviewTab({
    required this.summary,
    required this.month,
    required this.fmt,
    required this.fmtInt,
    required this.yearProfit,
    required this.overallProfit,
  });

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<RawMaterialType, double> _stock = {};
  bool _stockLoaded = false;

  // All-time buyer/worker account totals — independent of the selected
  // month, mirrors the Overview tab on the Buyer/Worker Accounts screens.
  double _buyerPending = 0;
  double _buyerPaid = 0;
  double _buyerSales = 0;
  double _workerEarned = 0;
  double _workerPaid = 0;
  double _workerBalance = 0;
  bool _accountsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadStock();
    _loadAccountsTotals();
  }

  Future<void> _loadStock() async {
    final stock = await FirebaseService.instance.getTotalStock();
    if (mounted) setState(() { _stock = stock; _stockLoaded = true; });
  }

  /// All-time totals across every buyer and every worker — same figures
  /// shown on the Buyer/Worker Accounts screens' Overview tabs, computed
  /// independently here since this widget doesn't share that screen's state.
  Future<void> _loadAccountsTotals() async {
    final svc = FirebaseService.instance;
    final allSales = await svc.getAllSales();
    final buyerTxs = await svc.allBuyerSimpleTransactionsStream().first;
    final workers = await svc.getWorkers();
    final workerTxs = await svc.allWorkerSimpleTransactionsStream().first;

    // ── Buyers: sales + manual dues (credit) minus payments (debit) ──────
    double buyerSales = 0;
    for (final sale in allSales) {
      if (sale.buyerId != null && sale.buyerId!.isNotEmpty) {
        buyerSales += sale.qty * sale.salePrice;
      }
    }
    double buyerPaid = 0;
    for (final tx in buyerTxs) {
      if (tx.type == SimpleTxType.credit) {
        buyerSales += tx.amount; // manual due, counts toward sales/owed
      } else {
        buyerPaid += tx.amount;
      }
    }

    // ── Workers: earnings (rate × kg across all sales) minus payments ────
    double workerEarned = 0;
    for (final worker in workers) {
      for (final sale in allSales) {
        final rate = sale.workerRatesPerKg[worker.role];
        if (rate != null) workerEarned += rate * sale.qty;
      }
    }
    double workerPaid = 0;
    for (final tx in workerTxs) {
      if (tx.type == WorkerSimpleTxType.debit) workerPaid += tx.amount;
    }

    if (mounted) {
      setState(() {
        _buyerSales = buyerSales;
        _buyerPaid = buyerPaid;
        _buyerPending = buyerSales - buyerPaid;
        _workerEarned = workerEarned;
        _workerPaid = workerPaid;
        _workerBalance = workerEarned - workerPaid;
        _accountsLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s       = widget.summary;
    final fmt     = widget.fmt;
    final fmtInt  = widget.fmtInt;
    final month   = widget.month;
    final yearProfit    = widget.yearProfit;
    final overallProfit = widget.overallProfit;
    final daysWithSales = s.dailyMap.length;
    final avgPerDay     = daysWithSales > 0 ? s.totalProfit / daysWithSales : 0.0;
    final netAfterExp   = s.totalProfit - s.totalExpenses;

    // ── Derived metrics for the extra KPI cards ─────────────────────────
    final profitMarginPct = s.totalRevenue > 0 ? (s.totalProfit / s.totalRevenue) * 100 : 0.0;
    final avgRatePerKg = s.totalKg > 0 ? s.totalRevenue / s.totalKg : 0.0;

    String bestCategory = '—';
    double bestCategoryProfit = 0;
    s.profitByCategory.forEach((cat, profit) {
      if (profit > bestCategoryProfit) {
        bestCategoryProfit = profit;
        bestCategory = cat;
      }
    });

    String bestDayLabel = '—';
    double bestDayProfit = 0;
    s.dailyMap.forEach((dateKey, profit) {
      if (profit > bestDayProfit) {
        bestDayProfit = profit;
        bestDayLabel = dateKey;
      }
    });
    final bestDayDisplay = bestDayLabel == '—'
        ? '—'
        : DateFormat('d MMM').format(DateTime.parse(bestDayLabel));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── KPI row 1 ──────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _kpi('Total profit', 'Rs ${fmtInt.format(s.totalProfit)}',
              s.totalProfit >= 30000 ? const Color(0xFF1A6B2A) : const Color(0xFF1F4E79),
              s.totalProfit >= 30000 ? const Color(0xFFC6EFCE) : const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Net (after expenses)',
              'Rs ${fmtInt.format(netAfterExp)}',
              netAfterExp >= 0 ? const Color(0xFF1A6B2A) : const Color(0xFFBB3333),
              netAfterExp >= 0 ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC))),
        ]),
        const SizedBox(height: 10),

        // ── KPI row 2 ──────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _kpi('Year Profit (${month.year})',
              'Rs ${fmtInt.format(yearProfit)}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Total Profit (All Time)',
              'Rs ${fmtInt.format(overallProfit)}',
              const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
        ]),
        const SizedBox(height: 10),

        // ── KPI row 3 ──────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _kpi('Total revenue', 'Rs ${fmtInt.format(s.totalRevenue)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Total kg sold', '${s.totalKg.toStringAsFixed(1)} kg',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 10),

        // ── KPI row 4 ──────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: _kpi('Sales days', '$daysWithSales days',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Avg per day', 'Rs ${fmtInt.format(avgPerDay)}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 10),

        // ── KPI row 5 (NEW) ──────────────────────────────────────────────
        Row(children: [
          Expanded(child: _kpi('Total expenses', 'Rs ${fmtInt.format(s.totalExpenses)}',
              const Color(0xFFBB3333), const Color(0xFFFFCCCC))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Profit margin', '${profitMarginPct.toStringAsFixed(1)}%',
              profitMarginPct >= 0 ? const Color(0xFF1A6B2A) : const Color(0xFFBB3333),
              profitMarginPct >= 0 ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC))),
        ]),
        const SizedBox(height: 10),

        // ── KPI row 6 (NEW) ──────────────────────────────────────────────
        Row(children: [
          Expanded(child: _kpi('Best category', bestCategory == '—'
                  ? '—' : '$bestCategory · Rs ${fmtInt.format(bestCategoryProfit)}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Best day', bestDayDisplay == '—'
                  ? '—' : '$bestDayDisplay · Rs ${fmtInt.format(bestDayProfit)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
        ]),
        const SizedBox(height: 16),

        // ── Material Stock Balance ──────────────────────────────────
        _sectionTitle('Material Stock Balance'),
        const SizedBox(height: 8),
        _buildStockBalanceCard(),
        const SizedBox(height: 16),

        // ── Buyer & Worker Accounts (All-Time) ───────────────────────────
        _sectionTitle('Buyer Accounts (All-Time)'),
        const SizedBox(height: 8),
        if (!_accountsLoaded)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else ...[
          Row(children: [
            Expanded(child: _kpi('Total Pending', 'Rs ${fmtInt.format(_buyerPending)}',
                const Color(0xFFCC4444), const Color(0xFFFFE5E5))),
            const SizedBox(width: 10),
            Expanded(child: _kpi('Total Paid', 'Rs ${fmtInt.format(_buyerPaid)}',
                const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
              child: _kpi('Total Sales (All Buyers)', 'Rs ${fmtInt.format(_buyerSales)}',
                  const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
        ],
        const SizedBox(height: 16),

        _sectionTitle('Worker Accounts (All-Time)'),
        const SizedBox(height: 8),
        if (!_accountsLoaded)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else ...[
          Row(children: [
            Expanded(child: _kpi('Total Earned', 'Rs ${fmtInt.format(_workerEarned)}',
                const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
            const SizedBox(width: 10),
            Expanded(child: _kpi('Total Paid', 'Rs ${fmtInt.format(_workerPaid)}',
                const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
              child: _kpi('Total Balance (All Workers)', 'Rs ${fmtInt.format(_workerBalance)}',
                  _workerBalance > 0 ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A),
                  _workerBalance > 0 ? const Color(0xFFFFE5E5) : const Color(0xFFC6EFCE))),
        ],
        const SizedBox(height: 16),

        // ── Target progress ───────────────────────────────────────────────
        _sectionTitle('Target: Rs 30,000'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Row(children: [
              Text('Rs ${fmtInt.format(s.totalProfit)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              const Text(' / Rs 30,000',
                  style: TextStyle(fontSize: 14, color: Color(0xFF888888))),
              const Spacer(),
              Text('${((s.totalProfit / 30000) * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: s.totalProfit >= 30000
                          ? const Color(0xFF1A6B2A) : const Color(0xFF1F4E79))),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (s.totalProfit / 30000).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation(
                    s.totalProfit >= 30000 ? const Color(0xFF639922)
                        : const Color(0xFF378ADD)),
              )),
            const SizedBox(height: 6),
            Text(
              s.totalProfit >= 30000
                  ? '✓ Target reached! +Rs ${fmtInt.format(s.totalProfit - 30000)} extra'
                  : 'Rs ${fmtInt.format(30000 - s.totalProfit)} more needed',
              style: TextStyle(fontSize: 11,
                  color: s.totalProfit >= 30000
                      ? const Color(0xFF1A6B2A) : const Color(0xFF888888)),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Category breakdown (NEW) ──────────────────────────────────────
        if (s.profitByCategory.isNotEmpty) ...[
          _sectionTitle('Profit & Volume by Category'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: s.profitByCategory.keys.map((cat) {
                final profit = s.profitByCategory[cat] ?? 0;
                final kg = s.kgByCategory[cat] ?? 0;
                final color = _categoryColor(cat);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹ ${fmtInt.format(profit)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${kg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF888888),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // ── Category profit-share pie chart (NEW) ──────────────────────
          _sectionTitle('Profit share by category'),
          const SizedBox(height: 8),
          _CategoryPieChart(
            profitByCategory: s.profitByCategory,
            fmtInt: fmtInt,
            categoryColor: _categoryColor,
          ),
          const SizedBox(height: 16),
        ],

        // ── Daily bar chart ───────────────────────────────────────────────
        if (s.dailyMap.isNotEmpty) ...[
          _sectionTitle('Daily profit — ${DateFormat('MMMM').format(month)}'),
          const SizedBox(height: 8),
          _DailyChart(dailyMap: s.dailyMap, month: month),
          const SizedBox(height: 16),
        ],

        // ── Calendar heatmap ──────────────────────────────────────────────
        _sectionTitle('Calendar'),
        const SizedBox(height: 8),
        _CalendarHeatmap(dailyMap: s.dailyMap, month: month),
        const SizedBox(height: 16),

        // ── Cost breakdown ─────────────────────────────────────────────────
        _sectionTitle('Cost breakdown'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            _costRow('Total expenses',   s.totalExpenses,  const Color(0xFFBB3333)),
            _costRow('Worker wages (attendance)', s.attendanceWages, const Color(0xFF7B4F06)),
            _costRow('Worker wages (auto/kg)',    s.autoWageTotal,   const Color(0xFF1F4E79)),
            const Divider(height: 16),
            _costRow('Net profit', s.netProfit,
                s.netProfit >= 0 ? const Color(0xFF1A6B2A) : const Color(0xFFBB3333),
                bold: true),
          ]),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Stock balance card: SS / Brass / Copper in 3 columns ─────────────
  Widget _buildStockBalanceCard() {
    final materials = [
      (RawMaterialType.ssSheet,     'SS',     const Color(0xFF1F4E79), const Color(0xFFE6F1FB)),
      (RawMaterialType.brassSheet,  'Brass',  const Color(0xFF7B4F06), const Color(0xFFFAEEDA)),
      (RawMaterialType.copperSheet, 'Copper', const Color(0xFFB85C38), const Color(0xFFFDE8DC)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _stockLoaded
          ? Row(
              children: materials.map((item) {
                final (type, label, color, bg) = item;
                final kg = _stock[type] ?? 0.0;
                final isNeg = kg < 0;
                final dispColor = isNeg ? const Color(0xFFBB3333) : color;
                final dispBg    = isNeg ? const Color(0xFFFFCCCC) : bg;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: dispBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.inventory_2_outlined, size: 12, color: dispColor),
                          const SizedBox(width: 4),
                          Text(label, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: dispColor)),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          '${kg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: dispColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isNeg ? 'Deficit' : 'In stock',
                          style: TextStyle(
                            fontSize: 10, color: dispColor.withOpacity(0.75)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
    );
  }

  Widget _kpi(String label, String value, Color color, Color bg) =>
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ]));

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333)));

  Widget _costRow(String label, double value, Color color, {bool bold = false}) =>
      Padding(padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
          Text('Rs ${NumberFormat('#,##0.00','en_IN').format(value)}',
              style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: color)),
        ]));

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'SS': return const Color(0xFF1F4E79);
      case 'Brass': return const Color(0xFF7B4F06);
      case 'Copper': return const Color(0xFFB85C38);
      default: return const Color(0xFF888888);
    }
  }
}

// ── Category profit-share pie chart (NEW) ──────────────────────────────────
class _CategoryPieChart extends StatelessWidget {
  final Map<String, double> profitByCategory;
  final NumberFormat fmtInt;
  final Color Function(String) categoryColor;
  const _CategoryPieChart({
    required this.profitByCategory,
    required this.fmtInt,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Only positive-profit categories make sense in a share-of-total pie.
    final entries = profitByCategory.entries.where((e) => e.value > 0).toList();
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    if (entries.isEmpty || total <= 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text('No profit to chart yet.',
            style: TextStyle(color: Color(0xFF888888)))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        SizedBox(
          height: 140,
          width: 140,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 32,
            sections: entries.map((e) {
              final pct = (e.value / total) * 100;
              final color = categoryColor(e.key);
              return PieChartSectionData(
                value: e.value,
                color: color,
                radius: 28,
                title: pct >= 8 ? '${pct.toStringAsFixed(0)}%' : '',
                titleStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.map((e) {
              final pct = (e.value / total) * 100;
              final color = categoryColor(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                  Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}


class _SalesTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt;
  const _SalesTab({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final entries = s.productMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Profit by product',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final parts = e.key.split('|');
              final name  = parts.length > 1 ? parts[1] : e.key;
              final pct   = s.totalProfit > 0 ? e.value / s.totalProfit : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    Text('Rs ${fmt.format(e.value)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B2A))),
                    const SizedBox(width: 6),
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct, minHeight: 5,
                        backgroundColor: const Color(0xFFEEEEEE),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF378ADD)),
                      )),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 16),
        const Text('All sales', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (s.sales.isEmpty)
          const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('No sales this month.', style: TextStyle(color: Color(0xFF888888)))))
        else
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: const BoxDecoration(color: Color(0xFF1F4E79),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: const Row(children: [
                  Expanded(flex: 1, child: Text('Date', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3, child: Text('Product', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Price/kg', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Profit', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ),
              ...s.sales.asMap().entries.map((e) {
                final i = e.key; final sale = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  color: i % 2 == 0 ? const Color(0xFFF8FAFB) : Colors.white,
                  child: Row(children: [
                    Expanded(flex: 1, child: Text(DateFormat('dd/MM').format(sale.date),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                    ),
                    Expanded(flex: 3, child: Text(sale.productName,
                        style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                    Expanded(flex: 1, child: Text(
                        '${sale.qty % 1 == 0 ? sale.qty.toInt() : sale.qty.toStringAsFixed(1)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 2, child: Text('Rs ${fmt.format(sale.salePrice)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF7B4F06)))),
                    Expanded(flex: 2, child: Text('Rs ${fmt.format(sale.profit)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B2A)))),
                  ]),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: const BoxDecoration(color: Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                child: Row(children: [
                  const Expanded(flex: 7, child: Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text(
                      'Rs ${fmt.format(s.totalProfit)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 12, color: Color(0xFF1A6B2A)))),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — BUYERS (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _BuyersTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt, fmtInt;
  const _BuyersTab({required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final buyers = summary.buyerList;
    final salesWithBuyer    = summary.sales.where((s) => s.buyerId != null && s.buyerId!.isNotEmpty).length;
    final salesWithoutBuyer = summary.sales.length - salesWithBuyer;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _card('Buyers this month', '${buyers.length}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _card('Total buyer profit',
              'Rs ${fmtInt.format(buyers.fold(0.0, (s, b) => s + b.totalProfit))}',
              const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
        ]),
        const SizedBox(height: 16),
        if (buyers.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text(
              'No buyer-linked sales this month.\nWhen adding a sale, select a buyer to track here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF888888)),
            )),
          )
        else ...[
          const Text('Sales by buyer',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...buyers.map((b) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 38, height: 38,
                      decoration: const BoxDecoration(
                          color: Color(0xFFE6F1FB), shape: BoxShape.circle),
                      child: Center(child: Text(
                          b.buyerName.isNotEmpty ? b.buyerName.substring(0,1).toUpperCase() : '?',
                          style: const TextStyle(color: Color(0xFF1F4E79),
                              fontWeight: FontWeight.bold, fontSize: 16)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.buyerName, style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('${b.salesCount} sales  •  ${b.totalKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  ])),
                ]),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _bstat('Total kg', '${b.totalKg.toStringAsFixed(1)} kg')),
                  Expanded(child: _bstat('Revenue', 'Rs ${fmtInt.format(b.totalRevenue)}')),
                  Expanded(child: _bstat('Profit',  'Rs ${fmtInt.format(b.totalProfit)}')),
                ]),
              ]),
            ),
          )),
        ],
        if (salesWithoutBuyer > 0) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 14, color: Color(0xFF888888)),
              const SizedBox(width: 8),
              Text('$salesWithoutBuyer sale(s) without buyer assigned.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ]),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _card(String label, String value, Color color, Color bg) =>
      Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ]));

  Widget _bstat(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
        color: Color(0xFF1A6B2A))),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
  ]);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 4 — WORKERS (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _WorkersTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt, fmtInt;
  const _WorkersTab({required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final Map<String, _WorkerWageStat> attendMap = {};
    for (final a in s.attendance.where((a) => a.present)) {
      attendMap[a.workerName] ??= _WorkerWageStat(a.workerName, a.workerRole);
      attendMap[a.workerName]!.days++;
      attendMap[a.workerName]!.totalWage += a.wage;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _card('Attendance wages',
              'Rs ${fmtInt.format(s.attendanceWages)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
          const SizedBox(width: 10),
          Expanded(child: _card('Auto wages (kg-based)',
              'Rs ${fmtInt.format(s.autoWageTotal)}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFF1F4E79)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Total kg sold this month: ${s.totalKg.toStringAsFixed(1)} kg\n'
              'Auto wage = kg sold × rate per kg (set in Workers → Auto Wages tab)',
              style: const TextStyle(fontSize: 11, color: Color(0xFF1F4E79)))),
          ]),
        ),
        const SizedBox(height: 16),

        if (s.autoWages.isNotEmpty) ...[
          const Text('Auto wages — from sales kg',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(color: Color(0xFF1F4E79),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: const Row(children: [
                  Expanded(flex: 3, child: Text('Worker', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Role', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Rate/kg', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Wage', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ),
              ...s.autoWages.asMap().entries.map((e) {
                final i = e.key; final w = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: i % 2 == 0 ? const Color(0xFFF8FAFB) : Colors.white,
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(w.worker.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text(w.worker.role,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888)))),
                    Expanded(flex: 2, child: Text('Rs ${fmt.format(w.ratePerKg)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 2, child: Text('Rs ${fmt.format(w.autoWage)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B2A)))),
                  ]),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(color: Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                child: Row(children: [
                  const Expanded(flex: 7, child: Text('Total auto wages',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Rs ${fmt.format(s.autoWageTotal)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 12, color: Color(0xFF1A6B2A)))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        if (attendMap.isNotEmpty) ...[
          const Text('Attendance wages — daily',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(color: Color(0xFF7B4F06),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                child: const Row(children: [
                  Expanded(flex: 3, child: Text('Worker', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Role', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 1, child: Text('Days', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text('Wages', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ),
              ...attendMap.values.toList().asMap().entries.map((e) {
                final i = e.key; final w = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: i % 2 == 0 ? const Color(0xFFF8FAFB) : Colors.white,
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(w.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text(w.role,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888)))),
                    Expanded(flex: 1, child: Text('${w.days}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 2, child: Text('Rs ${fmt.format(w.totalWage)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                            color: Color(0xFF7B4F06)))),
                  ]),
                );
              }),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(color: Color(0xFFFAEEDA),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12))),
                child: Row(children: [
                  const Expanded(flex: 6, child: Text('Total attendance wages',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Rs ${fmt.format(s.attendanceWages)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 12, color: Color(0xFF7B4F06)))),
                ]),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _card(String label, String value, Color color, Color bg) =>
      Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
            const SizedBox(height: 3),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ]));
}

class _WorkerWageStat {
  final String name, role;
  int days = 0;
  double totalWage = 0;
  _WorkerWageStat(this.name, this.role);
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 5 — EXPENSES (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _ExpensesTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt, fmtInt;
  const _ExpensesTab({required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final byCategory = s.expenseCatMap;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFFCCCC),
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.trending_down, color: Color(0xFFBB3333), size: 26),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total expenses this month',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
              Text('Rs ${fmtInt.format(s.totalExpenses)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                      color: Color(0xFFBB3333))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        if (byCategory.isNotEmpty) ...[
          const Text('By category', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: (byCategory.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _catIcon(e.key),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.key,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  'Rs ${fmt.format(e.value)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFBB3333),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(e.value / s.totalExpenses * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF888888),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: s.totalExpenses > 0
                                    ? e.value / s.totalExpenses
                                    : 0,
                                minHeight: 4,
                                backgroundColor: const Color(0xFFEEEEEE),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFBB3333),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        const Text('All expenses', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (s.expenses.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('No expenses this month.',
                style: TextStyle(color: Color(0xFF888888)))),
          )
        else
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: s.expenses.asMap().entries.map((e) {
              final i = e.key; final exp = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: i % 2 == 0 ? const Color(0xFFF8FAFB) : Colors.white,
                    borderRadius: BorderRadius.only(
                        topLeft:     i == 0 ? const Radius.circular(12) : Radius.zero,
                        topRight:    i == 0 ? const Radius.circular(12) : Radius.zero,
                        bottomLeft:  i == s.expenses.length-1 ? const Radius.circular(12) : Radius.zero,
                        bottomRight: i == s.expenses.length-1 ? const Radius.circular(12) : Radius.zero)),
                child: Row(children: [
                  _catIcon(exp.category),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(exp.description.isNotEmpty ? exp.description : exp.category,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    Text('${exp.category}  •  ${DateFormat('dd MMM').format(exp.date)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                  ])),
                  Text('Rs ${fmt.format(exp.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          color: Color(0xFFBB3333), fontSize: 14)),
                ]),
              );
            }).toList()),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _catIcon(String cat) {
    final map = {
      'Material': (Icons.construction, const Color(0xFF1F4E79)),
      'Runner':   (Icons.run_circle_outlined, const Color(0xFF7B4F06)),
      'Varai':    (Icons.build_outlined, const Color(0xFF1A6B2A)),
      'Plasma':   (Icons.electric_bolt_outlined, const Color(0xFF6A1B9A)),
      'Welding':  (Icons.whatshot_outlined, const Color(0xFFBF360C)),
      'Labour':   (Icons.people_outline, const Color(0xFF00695C)),
      'Polish':   (Icons.auto_fix_high_outlined, const Color(0xFF37474F)),
    };
    final (icon, color) = map[cat] ?? (Icons.category_outlined, const Color(0xFF888888));
    return Container(width: 32, height: 32,
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: color));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 6 — MATERIALS (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _MaterialsTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt, fmtInt;
  const _MaterialsTab({required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Map<String, double>>>(
      future: FirebaseService.instance.monthlyMaterialSummary(
        summary.sales.isNotEmpty ? summary.sales.first.date.year : DateTime.now().year,
        summary.sales.isNotEmpty ? summary.sales.first.date.month : DateTime.now().month,
      ),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final data = snap.data!;
        final materials = RawMaterialType.values.map((e) => e.displayName).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Raw Material Movement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...materials.map((mat) {
              final purchase = data[mat]?['purchase'] ?? 0;
              final sale = data[mat]?['sale'] ?? 0;
              return Card(
                child: ListTile(
                  title: Text(mat),
                  subtitle: Text('Purchased: ${purchase.toStringAsFixed(2)} kg  |  Sold: ${sale.toStringAsFixed(2)} kg'),
                  trailing: Text('Stock Δ: ${(purchase - sale).toStringAsFixed(2)} kg'),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 7 — FILTER  (date-range + buyer/material filter + inner sub-tabs)
// ══════════════════════════════════════════════════════════════════════════════
class _FilterTab extends StatefulWidget {
  const _FilterTab();
  @override
  State<_FilterTab> createState() => _FilterTabState();
}

enum _Preset { week, month, year, custom }

class _FilterTabState extends State<_FilterTab>
    with SingleTickerProviderStateMixin {
  final _svc    = FirebaseService.instance;
  final _fmt    = NumberFormat('#,##0.00', 'en_IN');
  final _fmtInt = NumberFormat('#,##0',    'en_IN');

  late TabController _innerTabs;

  _Preset  _preset   = _Preset.month;
  DateTime _start    = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _end      = DateTime.now();

  List<Buyer> _buyers   = [];
  String?     _buyerId;   // null = all buyers
  String?     _category;  // null = all categories

  RangeSummary? _summary;
  bool _loading = true;

  static const _categories = ['SS', 'Brass', 'Copper'];

  // Sub-tab labels & icons
  static const _subTabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Sales'),
    Tab(text: 'Buyers'),
    Tab(text: 'Workers'),
    Tab(text: 'Expenses'),
    Tab(text: 'Materials'),
  ];

  @override
  void initState() {
    super.initState();
    _innerTabs = TabController(length: _subTabs.length, vsync: this);
    _applyPreset(_Preset.month);
    _loadBuyers();
  }

  @override
  void dispose() {
    _innerTabs.dispose();
    super.dispose();
  }

  Future<void> _loadBuyers() async {
    final buyers = await _svc.getBuyers();
    if (mounted) setState(() => _buyers = buyers);
  }

  void _applyPreset(_Preset p) {
    final now = DateTime.now();
    DateTime start, end;
    switch (p) {
      case _Preset.week:
        final weekday = now.weekday;
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        end = now;
        break;
      case _Preset.month:
        start = DateTime(now.year, now.month, 1);
        end   = now;
        break;
      case _Preset.year:
        start = DateTime(now.year, 1, 1);
        end   = now;
        break;
      case _Preset.custom:
        start = _start;
        end   = _end;
        break;
    }
    setState(() {
      _preset = p;
      _start  = DateTime(start.year, start.month, start.day);
      _end    = DateTime(end.year,   end.month,   end.day);
    });
    _load();
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
        context: context, initialDate: _start,
        firstDate: DateTime(2020), lastDate: _end);
    if (d != null) {
      setState(() { _start = d; _preset = _Preset.custom; });
      _load();
    }
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
        context: context, initialDate: _end,
        firstDate: _start, lastDate: DateTime.now());
    if (d != null) {
      setState(() { _end = d; _preset = _Preset.custom; });
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await _svc.rangeSummary(
          start: _start, end: _end,
          buyerId: _buyerId, category: _category);
      if (mounted) setState(() { _summary = summary; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Filter controls (always visible) ─────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Preset chips
          const Text('Quick range',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: Color(0xFF555555))),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _presetChip('Week',  _Preset.week),
            _presetChip('Month', _Preset.month),
            _presetChip('Year',  _Preset.year),
            _presetChip('Custom',_Preset.custom),
          ]),
          const SizedBox(height: 10),
          // Date pickers
          Row(children: [
            Expanded(child: _dateBox('From', _start, _pickStart)),
            const SizedBox(width: 8),
            Expanded(child: _dateBox('To', _end, _pickEnd)),
          ]),
          const SizedBox(height: 10),
          // Buyer + Category dropdowns
          Row(children: [
            Expanded(child: _buyerDropdown()),
            const SizedBox(width: 8),
            Expanded(child: _categoryDropdown()),
          ]),
          const SizedBox(height: 10),
        ]),
      ),

      // ── Inner sub-tab bar ─────────────────────────────────────────────────
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _innerTabs,
          isScrollable: true,
          labelColor: const Color(0xFF1F4E79),
          unselectedLabelColor: const Color(0xFF888888),
          indicatorColor: const Color(0xFF1F4E79),
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: _subTabs,
        ),
      ),
      const Divider(height: 1),

      // ── Sub-tab content ───────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _summary == null
                ? const Center(child: Text('No data'))
                : TabBarView(
                    controller: _innerTabs,
                    children: [
                      _FilterOverviewSubTab(
                          summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _FilterSalesSubTab(
                          summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _FilterBuyersSubTab(
                          summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _FilterWorkersSubTab(
                          summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _FilterExpensesSubTab(
                          summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _FilterMaterialsSubTab(
                          summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                    ],
                  ),
      ),
    ]);
  }

  // ── shared helpers ─────────────────────────────────────────────────────────
  Widget _presetChip(String label, _Preset p) => ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: _preset == p,
    selectedColor: const Color(0xFF1F4E79),
    labelStyle: TextStyle(
        color: _preset == p ? Colors.white : const Color(0xFF333333)),
    onSelected: (_) =>
        p == _Preset.custom ? setState(() => _preset = p) : _applyPreset(p),
  );

  Widget _dateBox(String label, DateTime date, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300)),
          child: Row(children: [
            const Icon(Icons.calendar_today, size: 13, color: Color(0xFF1F4E79)),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF888888))),
              Text(DateFormat('dd MMM yy').format(date),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      );

  Widget _buyerDropdown() => DropdownButtonFormField<String?>(
    value: _buyerId,
    isExpanded: true,
    decoration: const InputDecoration(
        labelText: 'Buyer', isDense: true,
        border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
    items: [
      const DropdownMenuItem(value: null, child: Text('All buyers')),
      ..._buyers.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
    ],
    onChanged: (v) { setState(() => _buyerId = v); _load(); },
  );

  Widget _categoryDropdown() => DropdownButtonFormField<String?>(
    value: _category,
    isExpanded: true,
    decoration: const InputDecoration(
        labelText: 'Material', isDense: true,
        border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
    items: [
      const DropdownMenuItem(value: null, child: Text('All materials')),
      ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
    ],
    onChanged: (v) { setState(() => _category = v); _load(); },
  );
}

// ── Shared helper widgets for filter sub-tabs ─────────────────────────────────
Widget _filterKpi(String label, String value, Color color, Color bg) =>
    Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    );

Widget _filterSectionTitle(String t) => Text(t,
    style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333)));

Widget _filterEmptyCard(String text) => Container(
  padding: const EdgeInsets.all(24),
  decoration:
      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
  child: Center(
      child: Text(text, style: const TextStyle(color: Color(0xFF888888)))),
);

Color _filterCategoryColor(String cat) {
  switch (cat) {
    case 'SS':     return const Color(0xFF1F4E79);
    case 'Brass':  return const Color(0xFF7B4F06);
    case 'Copper': return const Color(0xFFB85C38);
    default:       return const Color(0xFF888888);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SUB-TAB 1 — OVERVIEW
// ══════════════════════════════════════════════════════════════════════════════
class _FilterOverviewSubTab extends StatefulWidget {
  final RangeSummary summary;
  final NumberFormat fmt, fmtInt;
  const _FilterOverviewSubTab(
      {required this.summary, required this.fmt, required this.fmtInt});

  @override
  State<_FilterOverviewSubTab> createState() => _FilterOverviewSubTabState();
}

class _FilterOverviewSubTabState extends State<_FilterOverviewSubTab> {
  Map<RawMaterialType, double> _stock = {};
  bool _stockLoaded = false;

  // Buyer/worker account totals scoped to the selected date range — mirrors
  // the all-time cards on the main Overview tab, but filtered to s.start..s.end.
  double _buyerPending = 0;
  double _buyerPaid = 0;
  double _buyerSales = 0;
  double _workerEarned = 0;
  double _workerPaid = 0;
  double _workerBalance = 0;
  bool _accountsLoaded = false;
  DateTime? _loadedStart;
  DateTime? _loadedEnd;

  @override
  void initState() {
    super.initState();
    _loadStock();
    _loadAccountsTotals();
  }

  @override
  void didUpdateWidget(_FilterOverviewSubTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The parent rebuilds this widget with a new summary whenever the date
    // range / buyer / category filter changes — reload the account totals
    // only when the range itself actually moved, to avoid refetching on
    // every rebuild.
    if (widget.summary.start != _loadedStart || widget.summary.end != _loadedEnd) {
      _loadAccountsTotals();
    }
  }

  Future<void> _loadStock() async {
    final stock = await FirebaseService.instance.getTotalStock();
    if (mounted) setState(() { _stock = stock; _stockLoaded = true; });
  }

  /// Buyer/worker totals restricted to [s.start, s.end] inclusive — same
  /// sales+dues−payments / earnings−payments math used everywhere else,
  /// just scoped to whatever range the Filter tab currently has selected.
  Future<void> _loadAccountsTotals() async {
    final svc = FirebaseService.instance;
    final start = widget.summary.start;
    final end = widget.summary.end;
    final endExclusive = end.add(const Duration(days: 1));

    bool inRange(DateTime d) => !d.isBefore(start) && d.isBefore(endExclusive);

    final allSales = await svc.getAllSales();
    final buyerTxs = await svc.allBuyerSimpleTransactionsStream().first;
    final workers = await svc.getWorkers();
    final workerTxs = await svc.allWorkerSimpleTransactionsStream().first;

    final salesInRange = allSales.where((s) => inRange(s.date)).toList();
    final buyerTxsInRange = buyerTxs.where((t) => inRange(t.dateTime)).toList();
    final workerTxsInRange = workerTxs.where((t) => inRange(t.dateTime)).toList();

    // ── Buyers: sales + manual dues (credit) minus payments (debit) ──────
    double buyerSales = 0;
    for (final sale in salesInRange) {
      if (sale.buyerId != null && sale.buyerId!.isNotEmpty) {
        buyerSales += sale.qty * sale.salePrice;
      }
    }
    double buyerPaid = 0;
    for (final tx in buyerTxsInRange) {
      if (tx.type == SimpleTxType.credit) {
        buyerSales += tx.amount;
      } else {
        buyerPaid += tx.amount;
      }
    }

    // ── Workers: earnings (rate × kg across sales in range) minus payments ─
    double workerEarned = 0;
    for (final worker in workers) {
      for (final sale in salesInRange) {
        final rate = sale.workerRatesPerKg[worker.role];
        if (rate != null) workerEarned += rate * sale.qty;
      }
    }
    double workerPaid = 0;
    for (final tx in workerTxsInRange) {
      if (tx.type == WorkerSimpleTxType.debit) workerPaid += tx.amount;
    }

    if (mounted) {
      setState(() {
        _buyerSales = buyerSales;
        _buyerPaid = buyerPaid;
        _buyerPending = buyerSales - buyerPaid;
        _workerEarned = workerEarned;
        _workerPaid = workerPaid;
        _workerBalance = workerEarned - workerPaid;
        _accountsLoaded = true;
        _loadedStart = start;
        _loadedEnd = end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final fmt    = widget.fmt;
    final fmtInt = widget.fmtInt;
    final avgRatePerKg =
        s.totalKg > 0 ? s.totalRevenue / s.totalKg : 0.0;
    final distinctBuyers = s.buyerList.length;
    final profitMarginPct =
        s.totalRevenue > 0 ? (s.totalProfit / s.totalRevenue) * 100 : 0.0;

    String bestCategory = '—';
    double bestCategoryProfit = 0;
    s.profitByCategory.forEach((cat, profit) {
      if (profit > bestCategoryProfit) {
        bestCategoryProfit = profit;
        bestCategory = cat;
      }
    });

    String bestDayDisplay = '—';
    double bestDayProfit = 0;
    s.dailyProfitMap.forEach((dateKey, profit) {
      if (profit > bestDayProfit) {
        bestDayProfit = profit;
        bestDayDisplay =
            DateFormat('d MMM').format(DateTime.parse(dateKey));
      }
    });

    // Auto-wage total from sales (mirrors monthly logic)
    final Map<String, double> autoWageByRole = {};
    for (final sale in s.sales) {
      sale.workerRatesPerKg.forEach((role, rate) {
        autoWageByRole[role] = (autoWageByRole[role] ?? 0) + rate * sale.qty;
      });
    }
    final totalAutoWage =
        autoWageByRole.values.fold(0.0, (a, b) => a + b);
    final netAfterWages = s.totalProfit - totalAutoWage;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // KPI row 1
        Row(children: [
          Expanded(child: _filterKpi('Total profit',
              'Rs ${fmtInt.format(s.totalProfit)}',
              const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Total revenue',
              'Rs ${fmtInt.format(s.totalRevenue)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
        ]),
        const SizedBox(height: 10),
        // KPI row 2
        Row(children: [
          Expanded(child: _filterKpi('Total kg sold',
              '${s.totalKg.toStringAsFixed(1)} kg',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Sales count', '${s.salesCount}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 10),
        // KPI row 3
        Row(children: [
          Expanded(child: _filterKpi('Avg profit / day',
              'Rs ${fmtInt.format(s.avgProfitPerDay)}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Avg kg / day',
              '${s.avgKgPerDay.toStringAsFixed(1)} kg',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 10),
        // KPI row 4
        Row(children: [
          Expanded(child: _filterKpi('Avg rate / kg',
              'Rs ${fmt.format(avgRatePerKg)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Buyers involved',
              '$distinctBuyers',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
        ]),
        const SizedBox(height: 10),
        // KPI row 5
        Row(children: [
          Expanded(child: _filterKpi('Profit margin',
              '${profitMarginPct.toStringAsFixed(1)}%',
              profitMarginPct >= 0
                  ? const Color(0xFF1A6B2A) : const Color(0xFFBB3333),
              profitMarginPct >= 0
                  ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Auto wages',
              'Rs ${fmtInt.format(totalAutoWage)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
        ]),
        const SizedBox(height: 10),
        // KPI row 6
        Row(children: [
          Expanded(child: _filterKpi('Net after wages',
              'Rs ${fmtInt.format(netAfterWages)}',
              netAfterWages >= 0
                  ? const Color(0xFF1A6B2A) : const Color(0xFFBB3333),
              netAfterWages >= 0
                  ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Best day',
              bestDayDisplay == '—'
                  ? '—'
                  : '$bestDayDisplay · Rs ${fmtInt.format(bestDayProfit)}',
              const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
        ]),
        const SizedBox(height: 10),
        // KPI row 7 — best category
        Row(children: [
          Expanded(child: _filterKpi('Best category',
              bestCategory == '—'
                  ? '—'
                  : '$bestCategory · Rs ${fmtInt.format(bestCategoryProfit)}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Days in range',
              '${s.daysInRange}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 18),

        // ── Material Stock Balance ─────────────────────────────────
        _filterSectionTitle('Material Stock Balance'),
        const SizedBox(height: 8),
        _buildFilterStockCard(),
        const SizedBox(height: 18),

        // ── Buyer & Worker Accounts (Selected Range) ─────────────────────
        _filterSectionTitle('Buyer Accounts (Selected Range)'),
        const SizedBox(height: 8),
        if (!_accountsLoaded)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else ...[
          Row(children: [
            Expanded(child: _filterKpi('Total Pending', 'Rs ${fmtInt.format(_buyerPending)}',
                const Color(0xFFCC4444), const Color(0xFFFFE5E5))),
            const SizedBox(width: 10),
            Expanded(child: _filterKpi('Total Paid', 'Rs ${fmtInt.format(_buyerPaid)}',
                const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
              child: _filterKpi('Total Sales (All Buyers)', 'Rs ${fmtInt.format(_buyerSales)}',
                  const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
        ],
        const SizedBox(height: 18),

        _filterSectionTitle('Worker Accounts (Selected Range)'),
        const SizedBox(height: 8),
        if (!_accountsLoaded)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: CircularProgressIndicator(strokeWidth: 2),
          ))
        else ...[
          Row(children: [
            Expanded(child: _filterKpi('Total Earned', 'Rs ${fmtInt.format(_workerEarned)}',
                const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
            const SizedBox(width: 10),
            Expanded(child: _filterKpi('Total Paid', 'Rs ${fmtInt.format(_workerPaid)}',
                const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          ]),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity,
              child: _filterKpi('Total Balance (All Workers)', 'Rs ${fmtInt.format(_workerBalance)}',
                  _workerBalance > 0 ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A),
                  _workerBalance > 0 ? const Color(0xFFFFE5E5) : const Color(0xFFC6EFCE))),
        ],
        const SizedBox(height: 18),

        // ── Profit trend chart ─────────────────────────────────────────
        _filterSectionTitle('Profit trend'),
        const SizedBox(height: 8),
        _RangeProfitChart(
            dailyMap: s.dailyProfitMap, start: s.start, end: s.end),
        const SizedBox(height: 18),

        // ── Category breakdown ─────────────────────────────────────────
        _filterSectionTitle('By material'),
        const SizedBox(height: 8),
        if (s.profitByCategory.isEmpty)
          _filterEmptyCard('No sales in this range.')
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: ['SS', 'Brass', 'Copper'].map((cat) {
                final profit   = s.profitByCategory[cat]   ?? 0;
                final kg       = s.kgByCategory[cat]       ?? 0;
                final revenue  = s.revenueByCategory[cat]  ?? 0;
                if (profit == 0 && kg == 0) return const SizedBox.shrink();
                final color = _filterCategoryColor(cat);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    Container(width: 12, height: 12,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(cat,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14))),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Rs ${fmtInt.format(profit)}',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color, fontSize: 14)),
                          Text(
                              '${kg.toStringAsFixed(1)} kg  •  '
                              'Rev Rs ${fmtInt.format(revenue)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF888888))),
                        ]),
                  ]),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildFilterStockCard() {
    final materials = [
      (RawMaterialType.ssSheet,     'SS',     const Color(0xFF1F4E79), const Color(0xFFE6F1FB)),
      (RawMaterialType.brassSheet,  'Brass',  const Color(0xFF7B4F06), const Color(0xFFFAEEDA)),
      (RawMaterialType.copperSheet, 'Copper', const Color(0xFFB85C38), const Color(0xFFFDE8DC)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _stockLoaded
          ? Row(
              children: materials.map((item) {
                final (type, label, color, bg) = item;
                final kg = _stock[type] ?? 0.0;
                final isNeg = kg < 0;
                final dispColor = isNeg ? const Color(0xFFBB3333) : color;
                final dispBg    = isNeg ? const Color(0xFFFFCCCC) : bg;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: dispBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.inventory_2_outlined, size: 12, color: dispColor),
                          const SizedBox(width: 4),
                          Text(label, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold, color: dispColor)),
                        ]),
                        const SizedBox(height: 6),
                        Text(
                          '${kg.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: dispColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isNeg ? 'Deficit' : 'In stock',
                          style: TextStyle(
                            fontSize: 10, color: dispColor.withOpacity(0.75)),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            )
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SUB-TAB 2 — SALES
// ══════════════════════════════════════════════════════════════════════════════
class _FilterSalesSubTab extends StatelessWidget {
  final RangeSummary summary;
  final NumberFormat fmt, fmtInt;
  const _FilterSalesSubTab(
      {required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    if (s.sales.isEmpty) {
      return Center(child: _filterEmptyCard('No sales in this range.'));
    }

    // Group sales by date descending
    final Map<String, List<Sale>> byDate = {};
    for (final sale in s.sales) {
      final dk = sale.date.toIso8601String().substring(0, 10);
      byDate.putIfAbsent(dk, () => []).add(sale);
    }
    final sortedDates = byDate.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary KPIs
        Row(children: [
          Expanded(child: _filterKpi('Total profit',
              'Rs ${fmtInt.format(s.totalProfit)}',
              const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Total kg',
              '${s.totalKg.toStringAsFixed(1)} kg',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _filterKpi('Revenue',
              'Rs ${fmtInt.format(s.totalRevenue)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('# Sales', '${s.salesCount}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 18),

        _filterSectionTitle('All sales'),
        const SizedBox(height: 8),
        ...sortedDates.map((dk) {
          final daySales = byDate[dk]!;
          final dayProfit =
              daySales.fold(0.0, (a, b) => a + b.profit);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.only(bottom: 6, top: 4),
                child: Row(children: [
                  Text(DateFormat('EEE, d MMM').format(DateTime.parse(dk)),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E79))),
                  const Spacer(),
                  Text('Rs ${fmtInt.format(dayProfit)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A6B2A))),
                ]),
              ),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                  children: daySales.asMap().entries.map((e) {
                    final i = e.key; final sale = e.value;
                    final color = _filterCategoryColor(sale.productCategory);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: i % 2 == 0
                              ? const Color(0xFFF8FAFB) : Colors.white,
                          borderRadius: BorderRadius.only(
                              topLeft: i == 0
                                  ? const Radius.circular(10) : Radius.zero,
                              topRight: i == 0
                                  ? const Radius.circular(10) : Radius.zero,
                              bottomLeft: i == daySales.length - 1
                                  ? const Radius.circular(10) : Radius.zero,
                              bottomRight: i == daySales.length - 1
                                  ? const Radius.circular(10) : Radius.zero)),
                      child: Row(children: [
                        Container(width: 8, height: 8,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sale.productName,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                              Text(
                                  '${sale.qty.toStringAsFixed(1)} kg  •  '
                                  'Rs ${fmt.format(sale.salePrice)}/kg'
                                  '${sale.buyerName != null && sale.buyerName!.isNotEmpty ? '  •  ${sale.buyerName}' : ''}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF888888))),
                            ])),
                        Text('Rs ${fmtInt.format(sale.profit)}',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold,
                                color: color)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
          );
        }),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SUB-TAB 3 — BUYERS
// ══════════════════════════════════════════════════════════════════════════════
class _FilterBuyersSubTab extends StatelessWidget {
  final RangeSummary summary;
  final NumberFormat fmt, fmtInt;
  const _FilterBuyersSubTab(
      {required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _filterKpi('Buyers involved',
              '${s.buyerList.length}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Total profit',
              'Rs ${fmtInt.format(s.totalProfit)}',
              const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
        ]),
        const SizedBox(height: 18),
        _filterSectionTitle('Buyer breakdown'),
        const SizedBox(height: 8),
        if (s.buyerList.isEmpty)
          _filterEmptyCard('No buyer-linked sales in this range.')
        else
          ...s.buyerList.map((b) {
            final pct = s.totalProfit > 0
                ? (b.totalProfit / s.totalProfit * 100) : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: const BoxDecoration(
                        color: Color(0xFFE6F1FB), shape: BoxShape.circle),
                    child: Center(child: Text(
                        b.buyerName.isNotEmpty
                            ? b.buyerName[0].toUpperCase() : '?',
                        style: const TextStyle(
                            color: Color(0xFF1F4E79),
                            fontWeight: FontWeight.bold,
                            fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.buyerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        Text(
                            '${b.salesCount} sales  •  '
                            '${b.totalKg.toStringAsFixed(1)} kg  •  '
                            '${pct.toStringAsFixed(0)}% of profit',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs ${fmtInt.format(b.totalProfit)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A6B2A), fontSize: 14)),
                        Text('Rev Rs ${fmtInt.format(b.totalRevenue)}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF888888))),
                      ]),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.totalProfit > 0
                        ? (b.totalProfit / s.totalProfit).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 5,
                    backgroundColor: const Color(0xFFEEEEEE),
                    valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF1A6B2A)),
                  ),
                ),
              ]),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SUB-TAB 4 — WORKERS
// ══════════════════════════════════════════════════════════════════════════════
class _FilterWorkersSubTab extends StatelessWidget {
  final RangeSummary summary;
  final NumberFormat fmt, fmtInt;
  const _FilterWorkersSubTab(
      {required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;

    // Compute auto wages per role from sales in this range
    final Map<String, double> autoWageByRole = {};
    for (final sale in s.sales) {
      sale.workerRatesPerKg.forEach((role, rate) {
        autoWageByRole[role] = (autoWageByRole[role] ?? 0) + rate * sale.qty;
      });
    }
    final totalAutoWage =
        autoWageByRole.values.fold(0.0, (a, b) => a + b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _filterKpi('Auto wages (range)',
              'Rs ${fmtInt.format(totalAutoWage)}',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Total kg sold',
              '${s.totalKg.toStringAsFixed(1)} kg',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFF1F4E79)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Auto wages are computed from kg sold × rate per kg '
              'for each worker role within the selected date range.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF1F4E79)))),
          ]),
        ),
        const SizedBox(height: 18),
        if (autoWageByRole.isEmpty)
          _filterEmptyCard('No auto wages in this range.')
        else ...[
          _filterSectionTitle('Auto wages by role'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(
                    color: Color(0xFF1F4E79),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12))),
                child: const Row(children: [
                  Expanded(flex: 4,
                      child: Text('Role',
                          style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3,
                      child: Text('Total kg',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.bold))),
                  Expanded(flex: 3,
                      child: Text('Wage',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: Colors.white,
                              fontSize: 11, fontWeight: FontWeight.bold))),
                ]),
              ),
              ...autoWageByRole.entries.toList().asMap().entries.map((e) {
                final i = e.key; final role = e.value.key;
                final wage = e.value.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  color: i % 2 == 0
                      ? const Color(0xFFF8FAFB) : Colors.white,
                  child: Row(children: [
                    Expanded(flex: 4,
                        child: Text(role,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500))),
                    Expanded(flex: 3,
                        child: Text(
                            '${s.totalKg.toStringAsFixed(1)} kg',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11))),
                    Expanded(flex: 3,
                        child: Text('Rs ${fmtInt.format(wage)}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A6B2A)))),
                  ]),
                );
              }),
              // Footer total
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: const BoxDecoration(
                    color: Color(0xFFF0F7FF),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12))),
                child: Row(children: [
                  const Expanded(flex: 7,
                      child: Text('Total auto wages',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 3,
                      child: Text('Rs ${fmtInt.format(totalAutoWage)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF1A6B2A)))),
                ]),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SUB-TAB 5 — EXPENSES
// ══════════════════════════════════════════════════════════════════════════════
class _FilterExpensesSubTab extends StatelessWidget {
  final RangeSummary summary;
  final NumberFormat fmt, fmtInt;
  const _FilterExpensesSubTab(
      {required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;

    // Derive expenses from sales' cost breakdown fields within the range
    // (same approach as monthly: cost categories come from product costs)
    final Map<String, double> costByRole = {};
    for (final sale in s.sales) {
      sale.workerRatesPerKg.forEach((role, rate) {
        costByRole[role] = (costByRole[role] ?? 0) + rate * sale.qty;
      });
    }
    final totalCost = costByRole.values.fold(0.0, (a, b) => a + b);
    final netAfterCost = s.totalProfit - totalCost;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _filterKpi('Worker cost (range)',
              'Rs ${fmtInt.format(totalCost)}',
              const Color(0xFFBB3333), const Color(0xFFFFCCCC))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Net after cost',
              'Rs ${fmtInt.format(netAfterCost)}',
              netAfterCost >= 0
                  ? const Color(0xFF1A6B2A) : const Color(0xFFBB3333),
              netAfterCost >= 0
                  ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC))),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3F3),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.info_outline,
                size: 14, color: Color(0xFFBB3333)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Expenses shown are worker auto-wages computed from sales '
              'in the selected range. Fixed expenses are tracked monthly.',
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFFBB3333)))),
          ]),
        ),
        const SizedBox(height: 18),

        if (costByRole.isEmpty)
          _filterEmptyCard('No cost data in this range.')
        else ...[
          _filterSectionTitle('Cost by role'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: (costByRole.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value)))
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(children: [
                          Row(children: [
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ),
                            Text('Rs ${fmt.format(e.value)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFBB3333))),
                            const SizedBox(width: 6),
                            Text(
                                totalCost > 0
                                    ? '${(e.value / totalCost * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF888888))),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: totalCost > 0
                                  ? (e.value / totalCost).clamp(0.0, 1.0)
                                  : 0,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFEEEEEE),
                              valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFBB3333)),
                            ),
                          ),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// FILTER SUB-TAB 6 — MATERIALS
// ══════════════════════════════════════════════════════════════════════════════
class _FilterMaterialsSubTab extends StatelessWidget {
  final RangeSummary summary;
  final NumberFormat fmt, fmtInt;
  const _FilterMaterialsSubTab(
      {required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    const cats = ['SS', 'Brass', 'Copper'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(child: _filterKpi('Total kg sold',
              '${s.totalKg.toStringAsFixed(1)} kg',
              const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
          const SizedBox(width: 10),
          Expanded(child: _filterKpi('Materials', '${s.kgByCategory.length}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 18),

        _filterSectionTitle('Material breakdown'),
        const SizedBox(height: 8),
        if (s.kgByCategory.isEmpty)
          _filterEmptyCard('No material data in this range.')
        else
          ...cats.map((cat) {
            final profit  = s.profitByCategory[cat]  ?? 0;
            final kg      = s.kgByCategory[cat]      ?? 0;
            final revenue = s.revenueByCategory[cat] ?? 0;
            if (kg == 0) return const SizedBox.shrink();
            final color = _filterCategoryColor(cat);
            final kgShare = s.totalKg > 0 ? kg / s.totalKg : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Center(child: Text(cat.substring(0, 1),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(
                            '${kg.toStringAsFixed(1)} kg  •  '
                            '${(kgShare * 100).toStringAsFixed(0)}% of total',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs ${fmtInt.format(profit)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: color, fontSize: 14)),
                        Text('Rev Rs ${fmtInt.format(revenue)}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF888888))),
                      ]),
                ]),
                const SizedBox(height: 10),
                // Profit bar
                Row(children: [
                  const Text('Profit ',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF555555))),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: s.totalProfit > 0
                          ? (profit / s.totalProfit).clamp(0.0, 1.0) : 0,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFEEEEEE),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  )),
                  const SizedBox(width: 6),
                  Text(
                      s.totalProfit > 0
                          ? '${(profit / s.totalProfit * 100).toStringAsFixed(0)}%'
                          : '0%',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                ]),
                const SizedBox(height: 4),
                // KG bar
                Row(children: [
                  const Text('Kg     ',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF555555))),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: kgShare.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFEEEEEE),
                      valueColor:
                          AlwaysStoppedAnimation(color.withOpacity(0.5)),
                    ),
                  )),
                  const SizedBox(width: 6),
                  Text('${(kgShare * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF888888))),
                ]),
              ]),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }
}

// Profit-trend bar chart over an arbitrary date range (not bound to a month).
class _RangeProfitChart extends StatelessWidget {
  final Map<String, double> dailyMap;
  final DateTime start, end;
  const _RangeProfitChart({required this.dailyMap, required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final totalDays = end.difference(start).inDays + 1;
    double maxVal = 1000;
    final bars = <BarChartGroupData>[];

    for (int i = 0; i < totalDays; i++) {
      final date = start.add(Duration(days: i));
      final key = date.toIso8601String().substring(0, 10);
      final val = dailyMap[key] ?? 0;
      if (val > maxVal) maxVal = val;
      bars.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: val,
          width: totalDays > 40 ? 3 : 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          color: val >= 1000 ? const Color(0xFF639922)
              : val >= 600 ? const Color(0xFF378ADD)
              : val > 0 ? const Color(0xFFEF9F27)
              : const Color(0xFFEEEEEE),
        ),
      ]));
    }

    // Avoid an unreadably dense x-axis for long ranges — show ~6 labels.
    final labelEvery = (totalDays / 6).ceil().clamp(1, totalDays);

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: BarChart(BarChartData(
        maxY: maxVal * 1.2,
        gridData: FlGridData(
          show: true, horizontalInterval: 500, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(
              v == 0 ? '' : '${(v / 1000).toStringAsFixed(1)}k',
              style: const TextStyle(fontSize: 9, color: Color(0xFF888888)),
            ),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, interval: labelEvery.toDouble(),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= totalDays) return const SizedBox.shrink();
              final date = start.add(Duration(days: i));
              return Text(DateFormat('d/M').format(date),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF888888)));
            },
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: bars,
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// YEAR VIEW (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _YearView extends StatelessWidget {
  final int year;
  final Map<int, double> yearMap;
  final void Function(int month) onMonthTap;
  const _YearView({required this.year, required this.yearMap, required this.onMonthTap});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final maxVal = yearMap.values.isEmpty ? 1.0
        : yearMap.values.reduce((a, b) => a > b ? a : b);
    final yearTotal = yearMap.values.fold(0.0, (a, b) => a + b);
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Year Overview — $year',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: Color(0xFF1F4E79))),
        const SizedBox(height: 4),
        Text('Total: Rs ${fmt.format(yearTotal)}',
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        const SizedBox(height: 16),

        if (yearMap.isNotEmpty)
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: BarChart(BarChartData(
              maxY: maxVal * 1.2,
              gridData: FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: maxVal / 4,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: Colors.grey.shade200, strokeWidth: 0.5)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(months[v.toInt() - 1],
                        style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
                  ),
                )),
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 40,
                  getTitlesWidget: (v, _) => Text(
                    v == 0 ? '' : '${(v/1000).toStringAsFixed(0)}k',
                    style: const TextStyle(fontSize: 8, color: Color(0xFF888888))),
                )),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: List.generate(12, (i) {
                final m   = i + 1;
                final val = yearMap[m] ?? 0;
                final isNow = m == now.month && year == now.year;
                return BarChartGroupData(x: m, barRods: [
                  BarChartRodData(
                    toY: val, width: 14,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    color: val >= 30000 ? const Color(0xFF639922)
                        : isNow ? const Color(0xFF1F4E79)
                        : val > 0 ? const Color(0xFF378ADD)
                        : const Color(0xFFEEEEEE),
                  ),
                ]);
              }),
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(y: 30000,
                    color: const Color(0xFF1A6B2A).withOpacity(0.4),
                    strokeWidth: 1, dashArray: [4, 4],
                    label: HorizontalLineLabel(show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(fontSize: 8, color: Color(0xFF1A6B2A)),
                        labelResolver: (_) => 'Target')),
              ]),
            )),
          ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10,
              childAspectRatio: 1.4),
          itemCount: 12,
          itemBuilder: (_, i) {
            final m   = i + 1;
            final val = yearMap[m] ?? 0;
            final isNow = m == now.month && year == now.year;
            final hasData = val > 0;
            final bg = val >= 30000 ? const Color(0xFFC6EFCE)
                : isNow ? const Color(0xFFE6F1FB)
                : hasData ? const Color(0xFFF5F5F5)
                : Colors.white;
            final textColor = val >= 30000 ? const Color(0xFF1A6B2A)
                : isNow ? const Color(0xFF1F4E79)
                : const Color(0xFF555555);

            return GestureDetector(
              onTap: () => onMonthTap(m),
              child: Container(
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isNow ? const Color(0xFF1F4E79) : const Color(0xFFEEEEEE))),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(months[i], style: TextStyle(fontSize: 13,
                      fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 3),
                  Text(hasData ? 'Rs ${fmt.format(val)}' : '—',
                      style: TextStyle(fontSize: 11, color: textColor)),
                  if (val >= 30000)
                    const Text('✓', style: TextStyle(fontSize: 10,
                        color: Color(0xFF1A6B2A))),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ── Daily chart ───────────────────────────────────────────────────────────────
class _DailyChart extends StatelessWidget {
  final Map<String, double> dailyMap;
  final DateTime month;
  const _DailyChart({required this.dailyMap, required this.month});

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    double maxVal = 1000;
    final bars = <BarChartGroupData>[];

    for (int d = 1; d <= days; d++) {
      final key = '${month.year.toString().padLeft(4,'0')}-'
          '${month.month.toString().padLeft(2,'0')}-'
          '${d.toString().padLeft(2,'0')}';
      final val = dailyMap[key] ?? 0;
      if (val > maxVal) maxVal = val;
      bars.add(BarChartGroupData(x: d, barRods: [
        BarChartRodData(
          toY: val, width: 6,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          color: val >= 1000 ? const Color(0xFF639922)
              : val >= 600 ? const Color(0xFF378ADD)
              : val > 0 ? const Color(0xFFEF9F27)
              : const Color(0xFFEEEEEE),
        ),
      ]));
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: BarChart(BarChartData(
        maxY: maxVal * 1.2,
        gridData: FlGridData(
          show: true, horizontalInterval: 500, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 0.5)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(
              v == 0 ? '' : '${(v/1000).toStringAsFixed(1)}k',
              style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
          )),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, interval: 5,
            getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
          )),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: bars,
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(y: 1000, strokeWidth: 1, dashArray: [4,4],
              color: const Color(0xFF1A6B2A).withOpacity(0.4),
              label: HorizontalLineLabel(show: true, alignment: Alignment.topRight,
                  style: const TextStyle(fontSize: 8, color: Color(0xFF1A6B2A)),
                  labelResolver: (_) => 'Rs 1k/day')),
        ]),
      )),
    );
  }
}

// ── Calendar heatmap ──────────────────────────────────────────────────────────
class _CalendarHeatmap extends StatelessWidget {
  final Map<String, double> dailyMap;
  final DateTime month;
  const _CalendarHeatmap({required this.dailyMap, required this.month});

  Color _col(double v) {
    if (v == 0) return const Color(0xFFF0F0F0);
    if (v >= 1000) return const Color(0xFF639922);
    if (v >= 800)  return const Color(0xFF97C459);
    if (v >= 600)  return const Color(0xFF378ADD);
    return const Color(0xFFEF9F27);
  }

  @override
  Widget build(BuildContext context) {
    final days     = DateUtils.getDaysInMonth(month.year, month.month);
    final firstDay = DateTime(month.year, month.month, 1).weekday % 7;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Row(children: ['S','M','T','W','T','F','S'].map((d) => Expanded(
          child: Center(child: Text(d, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF888888)))))).toList()),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: firstDay + days,
          itemBuilder: (_, i) {
            if (i < firstDay) return const SizedBox.shrink();
            final day = i - firstDay + 1;
            final key = '${month.year.toString().padLeft(4,'0')}-'
                '${month.month.toString().padLeft(2,'0')}-'
                '${day.toString().padLeft(2,'0')}';
            final profit = dailyMap[key] ?? 0;
            return Container(
              decoration: BoxDecoration(color: _col(profit), borderRadius: BorderRadius.circular(5)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(day.toString(), style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: profit >= 600 ? Colors.white : const Color(0xFF555555))),
                if (profit > 0)
                  Text('${(profit/1000).toStringAsFixed(1)}k',
                      style: TextStyle(fontSize: 8,
                          color: profit >= 600 ? Colors.white.withOpacity(0.85)
                              : const Color(0xFF555555))),
              ]),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _dot(const Color(0xFFEF9F27), '<600'),
          const SizedBox(width: 10),
          _dot(const Color(0xFF378ADD), '600-800'),
          const SizedBox(width: 10),
          _dot(const Color(0xFF97C459), '800-1k'),
          const SizedBox(width: 10),
          _dot(const Color(0xFF639922), '1k+'),
        ]),
      ]),
    );
  }

  Widget _dot(Color c, String label) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
  ]);
}