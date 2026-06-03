// lib/screens/monthly_screen.dart
// Full monthly report fetched from Firebase Firestore.
// Tabs: Overview | Sales | Buyers | Workers | Expenses
// Year view shows all 12 months at a glance.

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
  Map<int, double> _yearMap = {}; // month(1-12) → profit

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await _svc.monthlySummary(_month.year, _month.month);
      setState(() { _summary = summary; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _loadYearView() async {
    setState(() => _yearView = true);
    final Map<int, double> map = {};
    // Load all months in parallel
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
              // Month selector
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
                      _OverviewTab(summary: _summary!, month: _month, fmt: _fmt, fmtInt: _fmtInt),
                      _SalesTab(summary: _summary!, fmt: _fmt),
                      _BuyersTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _WorkersTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                      _ExpensesTab(summary: _summary!, fmt: _fmt, fmtInt: _fmtInt),
                    ],
                  ),
                ),
            ]),
    );
  }
}

// ── Month selector ────────────────────────────────────────────────────────────
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
// TAB 1 — OVERVIEW
// ══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final MonthlySummary summary;
  final DateTime month;
  final NumberFormat fmt, fmtInt;
  const _OverviewTab({required this.summary, required this.month,
      required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final daysWithSales = s.dailyMap.length;
    final avgPerDay     = daysWithSales > 0 ? s.totalProfit / daysWithSales : 0.0;
    final netAfterExp   = s.totalProfit - s.totalExpenses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── KPI row ──────────────────────────────────────────────────────
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
        Row(children: [
          Expanded(child: _kpi('Total revenue', 'Rs ${fmtInt.format(s.totalRevenue)}',
              const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Total kg sold', '${s.totalKg.toStringAsFixed(1)} kg',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _kpi('Sales days', '$daysWithSales days',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
          const SizedBox(width: 10),
          Expanded(child: _kpi('Avg per day', 'Rs ${fmtInt.format(avgPerDay)}',
              const Color(0xFF555555), const Color(0xFFF5F5F5))),
        ]),
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
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — SALES
// ══════════════════════════════════════════════════════════════════════════════
class _SalesTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt;
  const _SalesTab({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    // Product map already in summary
    final entries = s.productMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Product breakdown
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

        // All sales list
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
              // header
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
                        style: const TextStyle(fontSize: 11, color: Color(0xFF888888)))),
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
              // total row
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
// TAB 3 — BUYERS
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
        // Stats
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
// TAB 4 — WORKERS
// ══════════════════════════════════════════════════════════════════════════════
class _WorkersTab extends StatelessWidget {
  final MonthlySummary summary;
  final NumberFormat fmt, fmtInt;
  const _WorkersTab({required this.summary, required this.fmt, required this.fmtInt});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    // Group attendance wages by worker
    final Map<String, _WorkerWageStat> attendMap = {};
    for (final a in s.attendance.where((a) => a.present)) {
      attendMap[a.workerName] ??= _WorkerWageStat(a.workerName, a.workerRole);
      attendMap[a.workerName]!.days++;
      attendMap[a.workerName]!.totalWage += a.wage;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards
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

        // Auto wages — from sales kg
        if (s.autoWages.isNotEmpty) ...[
          const Text('Auto wages — from sales kg',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              // header
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
              // total
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

        // Attendance wages
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
// TAB 5 — EXPENSES
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
        // Total card
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

        // By category
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

        // All expenses
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
// YEAR VIEW
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

        // Bar chart
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

        // Month grid — tap to open
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