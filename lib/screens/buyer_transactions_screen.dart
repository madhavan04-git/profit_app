// lib/screens/buyer_transactions_screen.dart
// Fixed - Statement showing proper amounts with direct total amount edit

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_toast.dart';
import '../services/firebase_service.dart';

class BuyerTransactionsScreen extends StatefulWidget {
  final Buyer? buyer;
  const BuyerTransactionsScreen({super.key, this.buyer});

  @override
  State<BuyerTransactionsScreen> createState() => _BuyerTransactionsScreenState();
}

class _BuyerTransactionsScreenState extends State<BuyerTransactionsScreen>
    with SingleTickerProviderStateMixin {
  final _svc = FirebaseService.instance;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');
  Buyer? _selectedBuyer;

  // Tabs shown on the "all buyers" list screen: Overview | Buyers | Filter
  late TabController _listTabs;

  // Cache for statement data
  Map<String, List<StatementItem>> _statementCache = {};
  Map<String, double> _buyerSalesTotal = {};

  // Raw data cached once, re-sliced locally whenever the list-screen date
  // range changes — avoids re-fetching from Firestore on every date pick.
  List<Sale> _allSalesRaw = [];
  List<SimpleTransaction> _allBuyerTxRaw = [];

  // ── Filter state (statement view) ────────────────────────────────────────
  bool      _showFilter  = false;
  String    _filterType  = 'all';   // 'all' | 'credit' | 'debit'
  String    _searchQuery = '';
  DateTime? _filterFrom;
  DateTime? _filterTo;
  final _searchCtrl = TextEditingController();

  // ── Filter state (all-buyers Filter tab) ─────────────────────────────────
  String    _listSearchQuery = '';
  String    _listStatusFilter = 'all'; // 'all' | 'due' | 'advance'
  final _listSearchCtrl = TextEditingController();
  DateTime? _listFilterFrom;
  DateTime? _listFilterTo;

  @override
  void initState() {
    super.initState();
    _listTabs = TabController(length: 3, vsync: this);
    _selectedBuyer = widget.buyer;
    _loadAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _listSearchCtrl.dispose();
    _listTabs.dispose();
    super.dispose();
  }

  void _resetFilter() {
    setState(() {
      _showFilter  = false;
      _filterType  = 'all';
      _searchQuery = '';
      _filterFrom  = null;
      _filterTo    = null;
      _searchCtrl.clear();
    });
  }

  Future<void> _loadAllData() async {
    await _loadSalesTotals();
    if (_selectedBuyer != null) {
      await _refreshStatement(_selectedBuyer!.id!);
    }
  }

  Future<void> _loadSalesTotals() async {
    final allSales = await _svc.getAllSales();
    final allTx = await _svc.allBuyerSimpleTransactionsStream().first;
    _allSalesRaw = allSales;
    _allBuyerTxRaw = allTx;

    final Map<String, double> totals = {};
    for (final sale in allSales) {
      if (sale.buyerId != null && sale.buyerId!.isNotEmpty) {
        final amount = sale.qty * sale.salePrice;
        totals[sale.buyerId!] = (totals[sale.buyerId!] ?? 0) + amount;
      }
    }
    // Manual dues (credit entries not tied to a sale — e.g. opening balance,
    // an old due, an adjustment) must also count toward what the buyer owes.
    for (final tx in allTx) {
      if (tx.type == SimpleTxType.credit && tx.buyerId.isNotEmpty) {
        totals[tx.buyerId] = (totals[tx.buyerId] ?? 0) + tx.amount;
      }
    }
    setState(() => _buyerSalesTotal = totals);
  }

  /// Computes per-buyer {credit, debit, pending} either across all time
  /// (when from/to are null) or restricted to [from, to] inclusive — used to
  /// drive the Overview cards, Buyers list, and Filter tab together so a
  /// date range picked in Filter updates every tab consistently.
  Map<String, Map<String, double>> _computeBuyerBalances({
    required List<Buyer> buyers,
    required List<SimpleTransaction> liveTx,
    DateTime? from,
    DateTime? to,
  }) {
    final toExclusive = to?.add(const Duration(days: 1));

    bool inRange(DateTime d) {
      if (from != null && d.isBefore(from)) return false;
      if (toExclusive != null && !d.isBefore(toExclusive)) return false;
      return true;
    }

    final sales = (from == null && to == null)
        ? _allSalesRaw
        : _allSalesRaw.where((s) => inRange(s.date)).toList();
    // Prefer the live stream (kept fresh by StreamBuilder) but fall back to
    // the cached snapshot if the stream hasn't emitted yet.
    final txSource = liveTx.isNotEmpty ? liveTx : _allBuyerTxRaw;
    final txs = (from == null && to == null)
        ? txSource
        : txSource.where((t) => inRange(t.dateTime)).toList();

    final Map<String, double> salesTotal = {};
    for (final sale in sales) {
      if (sale.buyerId != null && sale.buyerId!.isNotEmpty) {
        salesTotal[sale.buyerId!] =
            (salesTotal[sale.buyerId!] ?? 0) + sale.qty * sale.salePrice;
      }
    }
    for (final tx in txs) {
      if (tx.type == SimpleTxType.credit && tx.buyerId.isNotEmpty) {
        salesTotal[tx.buyerId] = (salesTotal[tx.buyerId] ?? 0) + tx.amount;
      }
    }

    final Map<String, Map<String, double>> balances = {};
    for (final buyer in buyers) {
      double totalDebit = 0;
      for (final tx in txs) {
        if (tx.buyerId == buyer.id && tx.type == SimpleTxType.debit) {
          totalDebit += tx.amount;
        }
      }
      final totalSales = salesTotal[buyer.id!] ?? 0;
      balances[buyer.id!] = {
        'credit': totalSales,
        'debit': totalDebit,
        'pending': totalSales - totalDebit,
      };
    }
    return balances;
  }

  Future<void> _refreshStatement(String buyerId) async {
    final items = await _getStatementItems(buyerId);
    setState(() {
      _statementCache[buyerId] = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectedBuyer == null 
            ? const Text('Buyer Accounts')
            : Text('Statement - ${_selectedBuyer!.name}'),
        bottom: _selectedBuyer == null
            ? TabBar(
                controller: _listTabs,
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Buyers'),
                  Tab(text: 'Filter', icon: Icon(Icons.filter_alt_outlined, size: 16)),
                ],
              )
            : null,
        actions: [
          if (_selectedBuyer != null) ...[
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: (_filterType != 'all' || _filterFrom != null || _filterTo != null || _searchQuery.isNotEmpty)
                    ? const Color(0xFFEF9F27)
                    : null,
              ),
              tooltip: 'Filter',
              onPressed: () => setState(() => _showFilter = !_showFilter),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _refreshStatement(_selectedBuyer!.id!),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to all buyers',
              onPressed: () {
                _resetFilter();
                setState(() => _selectedBuyer = null);
              },
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () async {
                await _loadSalesTotals();
                setState(() {});
              },
            ),
        ],
      ),
      body: _selectedBuyer == null
          ? _buildAllBuyersTabs()
          : _buildBuyerStatementView(_selectedBuyer!),
      floatingActionButton:  null,
    );
  }


  /// Wraps the all-buyers data stream once and dispatches to the 3 list-screen
  /// tabs (Overview / Buyers / Filter) so all of them share the same balances
  /// computed from a single StreamBuilder pair — avoids recomputation drift.
  Widget _buildAllBuyersTabs() {
    return StreamBuilder<List<Buyer>>(
      stream: _svc.buyersStream(),
      builder: (ctx, buyersSnap) {
        if (buyersSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final buyers = buyersSnap.data ?? [];

        if (buyers.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No buyers yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Add buyers from the Buyers tab',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          );
        }

        return StreamBuilder<List<SimpleTransaction>>(
          stream: _svc.allBuyerSimpleTransactionsStream(),
          builder: (ctx, txsSnap) {
            final allTransactions = txsSnap.data ?? [];

            final buyerBalances = _computeBuyerBalances(
              buyers: buyers,
              liveTx: allTransactions,
              from: _listFilterFrom,
              to: _listFilterTo,
            );

            // ── Aggregate totals across ALL buyers for the Overview cards ──
            double grandPending = 0;
            double grandPaid = 0;
            double grandSales = 0;
            for (final b in buyerBalances.values) {
              grandSales   += b['credit']!;
              grandPaid    += b['debit']!;
              grandPending += b['pending']!;
            }

            final sortedBuyers = List<Buyer>.from(buyers);
            sortedBuyers.sort((a, b) =>
                (buyerBalances[b.id!]?['pending'] ?? 0).compareTo(buyerBalances[a.id!]?['pending'] ?? 0));

            return TabBarView(
              controller: _listTabs,
              children: [
                _buildBuyerOverviewTab(grandPending, grandPaid, grandSales, sortedBuyers, buyerBalances),
                _buildBuyerListTab(sortedBuyers, buyerBalances),
                _buildBuyerFilterTab(sortedBuyers, buyerBalances),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onRefreshAllBuyers() async {
    await _loadSalesTotals();
    setState(() {});
  }

  // ── TAB 1: Overview ──────────────────────────────────────────────────────
  Widget _buildBuyerOverviewTab(
    double grandPending,
    double grandPaid,
    double grandSales,
    List<Buyer> sortedBuyers,
    Map<String, Map<String, double>> buyerBalances,
  ) {
    final hasRange = _listFilterFrom != null || _listFilterTo != null;
    return RefreshIndicator(
      onRefresh: _onRefreshAllBuyers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasRange)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.date_range, size: 16, color: Color(0xFF7B4F06)),
                const SizedBox(width: 8),
                Expanded(child: Text(_rangeLabel(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: Color(0xFF7B4F06)))),
                GestureDetector(
                  onTap: () => setState(() {
                    _listFilterFrom = null;
                    _listFilterTo = null;
                  }),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF7B4F06)),
                ),
              ]),
            ),
          Row(children: [
            Expanded(child: _summaryCard(
                'Total Pending', grandPending, const Color(0xFFCC4444), const Color(0xFFFFE5E5))),
            const SizedBox(width: 10),
            Expanded(child: _summaryCard(
                'Total Paid', grandPaid, const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
          ]),
          const SizedBox(height: 10),
          _summaryCard(
              hasRange ? 'Total Sales (Selected Range)' : 'Total Sales (All Buyers)',
              grandSales, const Color(0xFF1F4E79), const Color(0xFFE6F1FB),
              fullWidth: true),
          const SizedBox(height: 20),

          Text('Top Buyers by Pending Amount',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
          const SizedBox(height: 10),

          ...sortedBuyers.take(5).map((buyer) {
            final bal = buyerBalances[buyer.id!]!;
            final pending = bal['pending']!;
            final isDebt = pending > 0;
            final color = isDebt ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                onTap: () => setState(() => _selectedBuyer = buyer),
                title: Text(buyer.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: buyer.phone.isNotEmpty ? Text(buyer.phone) : null,
                trailing: Text('Rs ${_fmt.format(pending.abs())}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ),
            );
          }),

          if (sortedBuyers.length > 5) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: () => _listTabs.animateTo(1),
                icon: const Icon(Icons.list, size: 18),
                label: Text('View all ${sortedBuyers.length} buyers'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _rangeLabel() {
    final df = DateFormat('dd MMM yyyy');
    if (_listFilterFrom != null && _listFilterTo != null) {
      return 'Showing: ${df.format(_listFilterFrom!)} – ${df.format(_listFilterTo!)}';
    } else if (_listFilterFrom != null) {
      return 'Showing: from ${df.format(_listFilterFrom!)}';
    } else if (_listFilterTo != null) {
      return 'Showing: up to ${df.format(_listFilterTo!)}';
    }
    return '';
  }

  Widget _summaryCard(String label, double value, Color color, Color bg, {bool fullWidth = false}) {
    final isNegative = value < 0;
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.75), fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Rs ${_fmt.format(value.abs())}${isNegative ? ' Cr' : ''}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // ── TAB 2: Buyers list (original behaviour) ──────────────────────────────
  Widget _buildBuyerListTab(
    List<Buyer> sortedBuyers,
    Map<String, Map<String, double>> buyerBalances,
  ) {
    return RefreshIndicator(
      onRefresh: _onRefreshAllBuyers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedBuyers.length,
        itemBuilder: (_, i) => _BuyerAccountCard(
          buyer: sortedBuyers[i],
          totalCredit: buyerBalances[sortedBuyers[i].id!]!['credit']!,
          totalDebit: buyerBalances[sortedBuyers[i].id!]!['debit']!,
          pending: buyerBalances[sortedBuyers[i].id!]!['pending']!,
          fmt: _fmt,
          onTap: () => setState(() => _selectedBuyer = sortedBuyers[i]),
          onAddPayment: () => _openPaymentForm(sortedBuyers[i]),
          onAddDue: () => _openDueForm(sortedBuyers[i]),
        ),
      ),
    );
  }

  // ── TAB 3: Filter (search + status filter across all buyers) ────────────
  Widget _buildBuyerFilterTab(
    List<Buyer> sortedBuyers,
    Map<String, Map<String, double>> buyerBalances,
  ) {
    var filtered = sortedBuyers.where((buyer) {
      final bal = buyerBalances[buyer.id!]!;
      final pending = bal['pending']!;

      if (_listStatusFilter == 'due' && pending <= 0) return false;
      if (_listStatusFilter == 'advance' && pending > 0) return false;

      if (_listSearchQuery.isNotEmpty) {
        final q = _listSearchQuery.toLowerCase();
        if (!buyer.name.toLowerCase().contains(q) &&
            !buyer.phone.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          color: const Color(0xFFF5F8FF),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _listSearchCtrl,
              onChanged: (v) => setState(() => _listSearchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search buyer name or phone…',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _listSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _listSearchCtrl.clear();
                          setState(() => _listSearchQuery = '');
                        })
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Date range (applies to totals everywhere)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _listDatePicker(
                label: _listFilterFrom == null
                    ? 'Start date'
                    : DateFormat('dd MMM yy').format(_listFilterFrom!),
                color: const Color(0xFF1F4E79),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _listFilterFrom ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: _listFilterTo ?? DateTime.now(),
                  );
                  if (d != null) setState(() => _listFilterFrom = d);
                },
                onClear: _listFilterFrom != null
                    ? () => setState(() => _listFilterFrom = null) : null,
              )),
              const SizedBox(width: 8),
              Expanded(child: _listDatePicker(
                label: _listFilterTo == null
                    ? 'End date'
                    : DateFormat('dd MMM yy').format(_listFilterTo!),
                color: const Color(0xFF1F4E79),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _listFilterTo ?? DateTime.now(),
                    firstDate: _listFilterFrom ?? DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _listFilterTo = d);
                },
                onClear: _listFilterTo != null
                    ? () => setState(() => _listFilterTo = null) : null,
              )),
            ]),
            const SizedBox(height: 12),
            const Text('Status',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF555555))),
            const SizedBox(height: 6),
            Row(children: [
              _statusChip('All', 'all', const Color(0xFF555555)),
              const SizedBox(width: 8),
              _statusChip('To Pay', 'due', const Color(0xFFCC4444)),
              const SizedBox(width: 8),
              _statusChip('Advance', 'advance', const Color(0xFF1A6B2A)),
            ]),
            if (_listStatusFilter != 'all' || _listSearchQuery.isNotEmpty ||
                _listFilterFrom != null || _listFilterTo != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _listStatusFilter = 'all';
                    _listSearchQuery = '';
                    _listSearchCtrl.clear();
                    _listFilterFrom = null;
                    _listFilterTo = null;
                  }),
                  icon: const Icon(Icons.filter_list_off, size: 16),
                  label: const Text('Clear all filters', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFCC4444)),
                ),
              ),
            ],
          ]),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search_off, size: 56, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text('No buyers match this filter',
                        style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _BuyerAccountCard(
                    buyer: filtered[i],
                    totalCredit: buyerBalances[filtered[i].id!]!['credit']!,
                    totalDebit: buyerBalances[filtered[i].id!]!['debit']!,
                    pending: buyerBalances[filtered[i].id!]!['pending']!,
                    fmt: _fmt,
                    onTap: () => setState(() => _selectedBuyer = filtered[i]),
                    onAddPayment: () => _openPaymentForm(filtered[i]),
                    onAddDue: () => _openDueForm(filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statusChip(String label, String value, Color color) => GestureDetector(
    onTap: () => setState(() => _listStatusFilter = value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _listStatusFilter == value ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: _listStatusFilter == value ? Colors.white : color)),
    ),
  );

  Widget _listDatePicker({
    required String label,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: Colors.grey.shade400)),
          ]),
        ),
      );


  // ── FILTER HELPERS ──────────────────────────────────────────────────────────
  List<StatementItem> _applyFilters(List<StatementItem> items) {
    return items.where((item) {
      // Type filter
      if (_filterType == 'credit' && item.type != 'credit') return false;
      if (_filterType == 'debit'  && item.type != 'debit')  return false;
      // Date range filter
      if (_filterFrom != null && item.date.isBefore(_filterFrom!)) return false;
      if (_filterTo   != null && item.date.isAfter(_filterTo!.add(const Duration(days: 1)))) return false;
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!item.description.toLowerCase().contains(q) &&
            !_fmt.format(item.amount).contains(q)) return false;
      }
      return true;
    }).toList();
  }

  bool get _hasActiveFilter =>
      _filterType != 'all' || _filterFrom != null || _filterTo != null || _searchQuery.isNotEmpty;

  Widget _buildFilterPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      height: _showFilter ? null : 0,
      child: _showFilter
          ? Container(
              color: const Color(0xFFF5F8FF),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search description or amount…',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            })
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),

                // Type filter chips
                const Text('Type',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: Color(0xFF555555))),
                const SizedBox(height: 6),
                Row(children: [
                  _typeChip('All',      'all',    const Color(0xFF555555)),
                  const SizedBox(width: 8),
                  _typeChip('Sales / Dues',  'credit', const Color(0xFFCC4444)),
                  const SizedBox(width: 8),
                  _typeChip('Payments', 'debit',  const Color(0xFF1A6B2A)),
                ]),
                const SizedBox(height: 12),

                // Date range row
                const Text('Date range',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold,
                        color: Color(0xFF555555))),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _datePicker(
                    label: _filterFrom == null
                        ? 'From'
                        : DateFormat('dd MMM yy').format(_filterFrom!),
                    icon: Icons.calendar_today,
                    color: const Color(0xFF1F4E79),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _filterFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: _filterTo ?? DateTime.now(),
                      );
                      if (d != null) setState(() => _filterFrom = d);
                    },
                    onClear: _filterFrom != null
                        ? () => setState(() => _filterFrom = null) : null,
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: _datePicker(
                    label: _filterTo == null
                        ? 'To'
                        : DateFormat('dd MMM yy').format(_filterTo!),
                    icon: Icons.calendar_today,
                    color: const Color(0xFF1F4E79),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _filterTo ?? DateTime.now(),
                        firstDate: _filterFrom ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _filterTo = d);
                    },
                    onClear: _filterTo != null
                        ? () => setState(() => _filterTo = null) : null,
                  )),
                ]),

                // Clear all
                if (_hasActiveFilter) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _resetFilter,
                      icon: const Icon(Icons.filter_list_off, size: 16),
                      label: const Text('Clear all filters',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFCC4444)),
                    ),
                  ),
                ],
              ]),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _typeChip(String label, String value, Color color) => GestureDetector(
    onTap: () => setState(() => _filterType = value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _filterType == value ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: _filterType == value ? Colors.white : color)),
    ),
  );

  Widget _datePicker({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 14, color: Colors.grey.shade400)),
          ]),
        ),
      );

  // ── SIMPLE STATEMENT VIEW like PhonePe/Google Pay ─────────────────────────
  Widget _buildBuyerStatementView(Buyer buyer) {
    final cachedItems = _statementCache[buyer.id!];
    
    if (cachedItems == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final statementItems = cachedItems;
    final filteredItems  = _applyFilters(statementItems);
    
    // Calculate totals from ALL items (unfiltered)
    double totalCredit = 0;
    double totalDebit  = 0;
    for (final item in statementItems) {
      if (item.type == 'credit') {
        totalCredit += item.amount;
      } else {
        totalDebit += item.amount;
      }
    }
    
    // Filtered totals for the banner
    double filteredCredit = 0;
    double filteredDebit  = 0;
    for (final item in filteredItems) {
      if (item.type == 'credit') filteredCredit += item.amount;
      else filteredDebit += item.amount;
    }

    final pending = totalCredit - totalDebit;
    
    // Group FILTERED items by date
    final Map<String, List<StatementItem>> groupedByDate = {};
    for (final item in filteredItems) {
      final dateKey = DateFormat('dd/MM/yyyy').format(item.date);
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(item);
    }
    
    // Sort dates (newest first)
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) {
        try {
          final dateA = DateFormat('dd/MM/yyyy').parseStrict(a);
          final dateB = DateFormat('dd/MM/yyyy').parseStrict(b);
          return dateB.compareTo(dateA);
        } catch (e) {
          return b.compareTo(a);
        }
      });
    
    return Column(children: [
      // Balance Card (always shows full totals)
      _BalanceCard(
        totalCredit: totalCredit,
        totalDebit: totalDebit,
        pending: pending,
        fmt: _fmt,
      ),

      // Filter panel (collapsible)
      _buildFilterPanel(),

      // Filtered result summary banner
      if (_hasActiveFilter)
        Container(
          color: const Color(0xFFFFF8E1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.filter_alt, size: 14, color: Color(0xFFEF9F27)),
            const SizedBox(width: 6),
            Expanded(child: Text(
              '${filteredItems.length} result${filteredItems.length == 1 ? '' : 's'}  •  '
              'Sales ₹${_fmt.format(filteredCredit)}  |  Paid ₹${_fmt.format(filteredDebit)}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF7B4F06)),
            )),
            GestureDetector(
              onTap: _resetFilter,
              child: const Icon(Icons.close, size: 16, color: Color(0xFF7B4F06)),
            ),
          ]),
        ),
      
      // Statement List
      Expanded(
        child: filteredItems.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  _hasActiveFilter
                      ? 'No transactions match the filter'
                      : 'No transactions yet',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600)),
                if (_hasActiveFilter) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _resetFilter,
                    child: const Text('Clear filters'),
                  ),
                ],
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sortedDates.length,
                itemBuilder: (_, i) {
                  final date = sortedDates[i];
                  final items = groupedByDate[date]!;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Items for this date
                        ...items.map((item) => _StatementItemRow(
                          item: item,
                          fmt: _fmt,
                          onEdit: () => _editStatementItem(buyer, item),
                        )),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Future<List<StatementItem>> _getStatementItems(String buyerId) async {
    final List<StatementItem> items = [];
    
    print('Getting statement for buyer: $buyerId');
    
    // Get all sales (Credit)
    final allSales = await _svc.getAllSales();
    print('Total sales found: ${allSales.length}');
    
    final salesForBuyer = allSales.where((s) => s.buyerId == buyerId).toList();
    print('Sales for this buyer: ${salesForBuyer.length}');
    
    for (final sale in salesForBuyer) {
      final amount = sale.qty * sale.salePrice;
      final isPieceProduct = sale.soldByPiece == true;
      final unit = isPieceProduct ? 'pcs' : 'kg';
      
      print('Sale: ${sale.productName} - ${sale.qty} $unit - Amount: $amount');
      items.add(StatementItem(
        id: 'sale_${sale.id}',
        date: sale.date,
        type: 'credit',
        amount: amount,
        description: isPieceProduct
            ? 'Sale: ${sale.productName} (${sale.qty} $unit @ ₹${_fmt.format(sale.salePrice)}/$unit)'
            : 'Sale: ${sale.productName} (${sale.qty} $unit @ ₹${_fmt.format(sale.salePrice)}/$unit)',
        originalData: {
          'saleId': sale.id,
          'qty': sale.qty,
          'salePrice': sale.salePrice,
          'productName': sale.productName,
          'soldByPiece': sale.soldByPiece ?? false,
          'unit': sale.unit ?? 'kg',
        },
      ));
    }
    
    // Get all manual buyer transactions (both manual dues = credit,
    // and payments received = debit).
    final manualTxs = await _svc.getBuyerSimpleTransactions(buyerId);
    print('Manual transactions for this buyer: ${manualTxs.length}');

    for (final tx in manualTxs) {
      if (tx.type == SimpleTxType.credit) {
        // Manual due — buyer owes this, not linked to a product sale.
        print('Manual due: ${tx.amount} - ${tx.note}');
        items.add(StatementItem(
          id: tx.id ?? '',
          date: tx.dateTime,
          type: 'credit',
          amount: tx.amount,
          description: tx.note.isNotEmpty ? tx.note : 'Manual due added',
          originalData: {'manualDueId': tx.id, 'note': tx.note},
        ));
      } else {
        print('Payment: ${tx.amount} - ${tx.note}');
        items.add(StatementItem(
          id: tx.id ?? '',
          date: tx.dateTime,
          type: 'debit',
          amount: tx.amount,
          description: tx.note.isNotEmpty ? tx.note : 'Payment Received',
          originalData: {'paymentId': tx.id, 'note': tx.note},
        ));
      }
    }
    
    // Sort by date (oldest first for running balance calculation)
    items.sort((a, b) => a.date.compareTo(b.date));
    
    // Calculate running balance
    double runningBalance = 0;
    for (int i = 0; i < items.length; i++) {
      if (items[i].type == 'credit') {
        runningBalance += items[i].amount;
      } else {
        runningBalance -= items[i].amount;
      }
      items[i].balance = runningBalance;
      print('Item ${i+1}: ${items[i].type} ${items[i].amount} - Balance: $runningBalance');
    }
    
    // Sort by date (newest first for display)
    items.sort((a, b) => b.date.compareTo(a.date));
    
    return items;
  }

  Future<void> _editStatementItem(Buyer buyer, StatementItem item) async {
    if (item.originalData?.containsKey('saleId') == true) {
      // Edit sale amount - DIRECT TOTAL AMOUNT EDIT
      await _showEditSaleAmountDialog(buyer, item);
    } else if (item.originalData?.containsKey('manualDueId') == true) {
      // Edit or delete a manual due entry
      await _showEditManualDueDialog(buyer, item);
    } else {
      // Edit payment
      await _showEditPaymentDialog(buyer, item);
    }
    
    // Refresh the statement
    await _refreshStatement(buyer.id!);
    await _loadSalesTotals();
    setState(() {});
  }

  // NEW: Direct total amount edit dialog - Just enter the total sale amount
  Future<void> _showEditSaleAmountDialog(Buyer buyer, StatementItem item) async {
    final saleId = item.originalData?['saleId'];
    final currentAmount = item.amount;
    final currentQty = item.originalData?['qty'] ?? 0.0;
    final currentPrice = item.originalData?['salePrice'] ?? 0.0;
    final isPieceProduct = item.originalData?['soldByPiece'] ?? false;
    final unit = isPieceProduct ? 'pcs' : 'kg';
    
    final amountController = TextEditingController(text: currentAmount.toString());
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double newAmount = double.tryParse(amountController.text) ?? 0;
          
          // Calculate new price based on new amount (keeping quantity same)
          // newAmount = qty * newPrice => newPrice = newAmount / qty
          double newPrice = currentQty > 0 ? newAmount / currentQty : 0;
          
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Text('Edit Sale Amount - ${buyer.name}'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product: ${item.originalData?['productName']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quantity: ${currentQty.toStringAsFixed(2)} $unit',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 16),
                        Text(
                          'Current Total: ₹${_fmt.format(currentAmount)}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '(₹${_fmt.format(currentPrice)} per $unit)',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Enter the total sale amount:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Amount (₹)',
                      hintText: 'Enter total amount',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.currency_rupee),
                      suffixText: '₹',
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'New Calculation:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('New Price per $unit:', style: const TextStyle(fontSize: 12)),
                            Text(
                              '₹${_fmt.format(newPrice)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'New Total Amount:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              '₹ ${_fmt.format(newAmount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text);
                  
                  if (newAmount != null && newAmount > 0 && saleId != null) {
                    // Calculate new price
                    final newPrice = newAmount / currentQty;
                    
                    // Update the sale in Firebase with new price (keeping quantity same)
                    await _svc.updateSalePrice(saleId, newPrice);
                    
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sale amount updated from ₹${_fmt.format(currentAmount)} to ₹${_fmt.format(newAmount)}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditPaymentDialog(Buyer buyer, StatementItem item) async {
    final paymentId = item.originalData?['paymentId'];
    final currentAmount = item.amount;
    final currentNote = item.originalData?['note'] ?? '';
    
    final amountController = TextEditingController(text: currentAmount.toString());
    final noteController = TextEditingController(text: currentNote);
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF1F4E79)),
            const SizedBox(width: 8),
            Text('Edit Payment - ${buyer.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton.icon(
            onPressed: () async {
              if (paymentId != null) {
                await _svc.deleteSimpleTransaction(paymentId);
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment deleted')),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text);
              final newNote = noteController.text;
              
              if (newAmount != null && newAmount > 0 && paymentId != null) {
                await _svc.updateSimpleTransaction(
                  paymentId,
                  amount: newAmount,
                  note: newNote,
                );
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment updated successfully')),
                );
              }
            },
            icon: const Icon(Icons.update),
            label: const Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Edit or delete a manual due (a credit entry the buyer owes that isn't
  // tied to a product sale — e.g. an opening balance, an old due, an
  // adjustment you're noting by hand).
  Future<void> _showEditManualDueDialog(Buyer buyer, StatementItem item) async {
    final dueId = item.originalData?['manualDueId'];
    final currentAmount = item.amount;
    final currentNote = item.originalData?['note'] ?? '';

    final amountController = TextEditingController(text: currentAmount.toString());
    final noteController = TextEditingController(text: currentNote);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFFCC4444)),
            const SizedBox(width: 8),
            Text('Edit Due - ${buyer.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton.icon(
            onPressed: () async {
              if (dueId != null) {
                await _svc.deleteSimpleTransaction(dueId);
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Due removed')),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text);
              final newNote = noteController.text;

              if (newAmount != null && newAmount > 0 && dueId != null) {
                await _svc.updateSimpleTransaction(
                  dueId,
                  amount: newAmount,
                  note: newNote,
                );
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Due updated successfully')),
                );
              }
            },
            icon: const Icon(Icons.update),
            label: const Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC4444),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyStatement() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No transactions yet',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade400,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Add sales or payments to see statement',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ]),
  );

  Future<void> _openPaymentForm(Buyer buyer) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentForm(
        buyer: buyer, 
        onSaved: () async {
          await _loadSalesTotals();
          await _refreshStatement(buyer.id!);
          setState(() {});
        },
      ),
    );
  }

  Future<void> _openDueForm(Buyer buyer) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DueForm(
        buyer: buyer,
        onSaved: () async {
          await _loadSalesTotals();
          await _refreshStatement(buyer.id!);
          setState(() {});
        },
      ),
    );
  }
}

// ── Statement Item Model (UPDATED with originalData) ──────────────────────────────
class StatementItem {
  final String id;
  final DateTime date;
  final String type; // 'credit' or 'debit'
  double amount;
  final String description;
  double balance;
  final Map<String, dynamic>? originalData;

  StatementItem({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.balance = 0,
    this.originalData,
  });
}

// ── Buyer Account Card ─────────────────────────────────────────────────
class _BuyerAccountCard extends StatelessWidget {
  final Buyer buyer;
  final double totalCredit;
  final double totalDebit;
  final double pending;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onAddPayment;
  final VoidCallback onAddDue;

  const _BuyerAccountCard({
    required this.buyer,
    required this.totalCredit,
    required this.totalDebit,
    required this.pending,
    required this.fmt,
    required this.onTap,
    required this.onAddPayment,
    required this.onAddDue,
  });

  @override
  Widget build(BuildContext context) {
    final isDebt = pending > 0;
    final statusColor = isDebt ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(buyer.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (buyer.phone.isNotEmpty)
                  Text(buyer.phone,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            )),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(children: [
                Text(isDebt ? 'To Pay' : 'Advance',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                Text('Rs ${fmt.format(pending.abs())}',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
              ]),
            ),
          ]),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(child: Column(children: [
                const Text('Total Sales',
                    style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                Text('Rs ${fmt.format(totalCredit)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1F4E79))),
              ])),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              Expanded(child: Column(children: [
                const Text('Total Paid',
                    style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                Text('Rs ${fmt.format(totalDebit)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1A6B2A))),
              ])),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              Expanded(child: Column(children: [
                const Text('Pending',
                    style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                Text('Rs ${fmt.format(pending.abs())}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: statusColor)),
              ])),
            ]),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddDue,
                  icon: const Icon(Icons.add_card, size: 18),
                  label: const Text('Add Due'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFCC4444)),
                    foregroundColor: const Color(0xFFCC4444),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddPayment,
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Add Payment'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF1F4E79)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.receipt_long, size: 18),
              label: const Text('View Statement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Balance Card ──────────────────────────────────────────────────────
class _BalanceCard extends StatelessWidget {
  final double totalCredit;
  final double totalDebit;
  final double pending;
  final NumberFormat fmt;

  const _BalanceCard({
    required this.totalCredit,
    required this.totalDebit,
    required this.pending,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isDebt = pending > 0;
    final color = isDebt ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1F4E79), const Color(0xFF2E6FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        const Text(
          'Current Balance',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rs ${fmt.format(pending.abs())}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isDebt ? 'You have to receive this amount' : 'Advance balance',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(children: [
                const Text('Total Sales', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Rs ${fmt.format(totalCredit)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
            Container(width: 1, height: 30, color: Colors.white24),
            Expanded(
              child: Column(children: [
                const Text('Total Paid', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Rs ${fmt.format(totalDebit)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Statement Item Row (UPDATED with Edit button) ─────────────────────────────
class _StatementItemRow extends StatelessWidget {
  final StatementItem item;
  final NumberFormat fmt;
  final VoidCallback onEdit;

  const _StatementItemRow({
    required this.item,
    required this.fmt,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = item.type == 'credit';
    final isManualDue = item.originalData?.containsKey('manualDueId') == true;
    final amountColor = isCredit ? const Color(0xFF1A6B2A) : const Color(0xFFCC4444);
    final amountPrefix = isCredit ? '+' : '-';
    final title = isManualDue ? '📌 Due' : (isCredit ? '💰 Sale' : '💳 Payment');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F4E79).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, size: 12, color: Color(0xFF1F4E79)),
                              SizedBox(width: 2),
                              Text('Edit', style: TextStyle(fontSize: 10, color: Color(0xFF1F4E79))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amountPrefix ₹ ${fmt.format(item.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ₹ ${fmt.format(item.balance)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Payment Form ────────────────────────────────────────────────────────
class _PaymentForm extends StatefulWidget {
  final Buyer buyer;
  final VoidCallback onSaved;
  
  const _PaymentForm({required this.buyer, required this.onSaved});

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final amountStr = _amountCtrl.text.trim();
    if (amountStr.isEmpty) return;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final tx = SimpleTransaction(
      buyerId: widget.buyer.id!,
      buyerName: widget.buyer.name,
      type: SimpleTxType.debit,
      amount: amount,
      note: _noteCtrl.text.trim(),
      dateTime: dt,
    );
    await FirebaseService.instance.addSimpleTransaction(tx);
    widget.onSaved();
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      AppToast.showWith(messenger, ToastEvent.payment,
          name: widget.buyer.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        Text('Add Payment — ${widget.buyer.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Record payment received from buyer',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 20),

        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (₹) *',
            prefixText: '₹ ',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date),
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.access_time_outlined,
                    size: 16, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Text(_time.format(context),
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
          )),
        ]),
        const SizedBox(height: 10),

        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. payment received',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B2A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ))
                : const Text('Save Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

// ── Manual Due Form ─────────────────────────────────────────────────────
// Records that a buyer owes you a specific amount that is NOT linked to a
// product sale — e.g. an opening balance carried over, an old due you're
// noting for the first time, or a manual correction. Internally this is a
// SimpleTransaction with type=credit, the same type sales auto-generate
// against the buyer's balance, so the existing pending-amount math (sales +
// credits − payments) picks it up automatically everywhere.
class _DueForm extends StatefulWidget {
  final Buyer buyer;
  final VoidCallback onSaved;

  const _DueForm({required this.buyer, required this.onSaved});

  @override
  State<_DueForm> createState() => _DueFormState();
}

class _DueFormState extends State<_DueForm> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final amountStr = _amountCtrl.text.trim();
    if (amountStr.isEmpty) return;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final tx = SimpleTransaction(
      buyerId: widget.buyer.id!,
      buyerName: widget.buyer.name,
      type: SimpleTxType.credit, // credit = buyer owes this amount
      amount: amount,
      note: _noteCtrl.text.trim(),
      dateTime: dt,
    );
    await FirebaseService.instance.addSimpleTransaction(tx);
    widget.onSaved();
    if (mounted) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      AppToast.showWith(messenger, ToastEvent.due, name: widget.buyer.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        Text('Add Due — ${widget.buyer.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Note an amount this buyer owes you (not tied to a sale)',
            style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 20),

        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (₹) *',
            prefixText: '₹ ',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFFCC4444)),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date),
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.access_time_outlined,
                    size: 16, color: Color(0xFFCC4444)),
                const SizedBox(width: 8),
                Text(_time.format(context),
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
          )),
        ]),
        const SizedBox(height: 10),

        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. old balance, opening due, adjustment',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ))
                : const Text('Save Due',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}