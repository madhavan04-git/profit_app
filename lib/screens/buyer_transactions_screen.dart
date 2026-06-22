// lib/screens/buyer_transactions_screen.dart
// Fixed - Statement showing proper amounts with direct total amount edit

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class BuyerTransactionsScreen extends StatefulWidget {
  final Buyer? buyer;
  const BuyerTransactionsScreen({super.key, this.buyer});

  @override
  State<BuyerTransactionsScreen> createState() => _BuyerTransactionsScreenState();
}

class _BuyerTransactionsScreenState extends State<BuyerTransactionsScreen> {
  final _svc = FirebaseService.instance;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');
  Buyer? _selectedBuyer;
  
  // Cache for statement data
  Map<String, List<StatementItem>> _statementCache = {};
  Map<String, double> _buyerSalesTotal = {};

  // ── Filter state (statement view) ────────────────────────────────────────
  bool      _showFilter  = false;
  String    _filterType  = 'all';   // 'all' | 'credit' | 'debit'
  String    _searchQuery = '';
  DateTime? _filterFrom;
  DateTime? _filterTo;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBuyer = widget.buyer;
    _loadAllData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    final Map<String, double> totals = {};
    for (final sale in allSales) {
      if (sale.buyerId != null && sale.buyerId!.isNotEmpty) {
        final amount = sale.qty * sale.salePrice;
        totals[sale.buyerId!] = (totals[sale.buyerId!] ?? 0) + amount;
      }
    }
    // Manual dues (credit entries not tied to a sale — e.g. opening balance,
    // an old due, an adjustment) must also count toward what the buyer owes.
    final allTx = await _svc.allBuyerSimpleTransactionsStream().first;
    for (final tx in allTx) {
      if (tx.type == SimpleTxType.credit && tx.buyerId.isNotEmpty) {
        totals[tx.buyerId] = (totals[tx.buyerId] ?? 0) + tx.amount;
      }
    }
    setState(() => _buyerSalesTotal = totals);
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
          ],
        ],
      ),
      body: _selectedBuyer == null
          ? _buildAllBuyersView()
          : _buildBuyerStatementView(_selectedBuyer!),
      floatingActionButton: _selectedBuyer != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'addDue',
                  onPressed: () => _openDueForm(_selectedBuyer!),
                  icon: const Icon(Icons.add_card),
                  label: const Text('Add Due'),
                  backgroundColor: const Color(0xFFCC4444),
                  foregroundColor: Colors.white,
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'addPayment',
                  onPressed: () => _openPaymentForm(_selectedBuyer!),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Payment'),
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildAllBuyersView() {
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
            
            final Map<String, Map<String, double>> buyerBalances = {};
            
            for (final buyer in buyers) {
              final buyerTxs = allTransactions.where((tx) => tx.buyerId == buyer.id).toList();

              // Only debit (payments received) is summed here — manual credit
              // (dues) is already folded into _buyerSalesTotal in
              // _loadSalesTotals(), so summing it again here would double it.
              double totalDebit = 0;
              for (final tx in buyerTxs) {
                if (tx.type == SimpleTxType.debit) {
                  totalDebit += tx.amount;
                }
              }

              // totalSales here = sales + any manual dues (see _loadSalesTotals).
              final totalSales = _buyerSalesTotal[buyer.id!] ?? 0;
              final pending = totalSales - totalDebit;
              
              buyerBalances[buyer.id!] = {
                'credit': totalSales,
                'debit': totalDebit,
                'pending': pending,
              };
            }
            
            final sortedBuyers = List<Buyer>.from(buyers);
            sortedBuyers.sort((a, b) => 
                (buyerBalances[b.id!]?['pending'] ?? 0).compareTo(buyerBalances[a.id!]?['pending'] ?? 0));
            
            return RefreshIndicator(
              onRefresh: () async {
                await _loadSalesTotals();
                setState(() {});
              },
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
          },
        );
      },
    );
  }

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
    if (mounted) Navigator.pop(context);
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
    if (mounted) Navigator.pop(context);
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