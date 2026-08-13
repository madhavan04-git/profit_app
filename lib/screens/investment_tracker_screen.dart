// lib/screens/investment_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/app_toast.dart';
import '../services/firebase_service.dart';
import 'pattarai_stock_screen.dart';

class InvestmentTrackerScreen extends StatefulWidget {
  const InvestmentTrackerScreen({super.key});

  @override
  State<InvestmentTrackerScreen> createState() => _InvestmentTrackerScreenState();
}

class _InvestmentTrackerScreenState extends State<InvestmentTrackerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _svc = FirebaseService.instance;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');

  Map<RawMaterialType, double> _stock = {};
  bool _loadingStock = true;
  double _lowStockThreshold = 0;
  int _dataVersion = 0;

  // ── track which tab is active so FAB shows only on Inventory ──
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _currentTab = _tabController.index);
    });
    _loadStock();
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final s = await _svc.getAppSettings();
    setState(() => _lowStockThreshold = s.lowStockThresholdKg);
  }

  Future<void> _loadStock() async {
    final stock = await _svc.getTotalStock();
    setState(() {
      _stock = stock;
      _loadingStock = false;
      _dataVersion++; // tells the Parties tab its balances are out of date
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment Tracker'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Inventory', icon: Icon(Icons.inventory)),
            Tab(text: 'Transactions', icon: Icon(Icons.history)),
            Tab(text: 'Parties', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InventoryTab(
            stock: _stock,
            loading: _loadingStock,
            fmt: _fmt,
            onRefresh: _loadStock,
            lowStockThreshold: _lowStockThreshold,
          ),
          _TransactionsTab(fmt: _fmt, onRefresh: _loadStock),
          // dataVersion bumps whenever stock changes, so the Parties tab
          // re-reads balances after a delete instead of showing stale kg.
          _PartiesTab(
              fmt: _fmt, onRefresh: _loadStock, dataVersion: _dataVersion),
        ],
      ),
      // ── FAB only visible on Inventory tab (index 0) ──
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddTransactionSheet(),
              icon: const Icon(Icons.add),
              label: const Text('Add Purchase/Sale'),
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMaterialTransactionSheet(onSaved: _loadStock),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Inventory Tab (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _InventoryTab extends StatelessWidget {
  final Map<RawMaterialType, double> stock;
  final bool loading;
  final NumberFormat fmt;
  final VoidCallback onRefresh;
  final double lowStockThreshold;

  const _InventoryTab({
    required this.stock,
    required this.loading,
    required this.fmt,
    required this.onRefresh,
    this.lowStockThreshold = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final metals = MaterialMetal.values;
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        // One extra row at the top for the Sheet / Wastage entry point.
        itemCount: metals.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SheetWastageButton(onReturn: onRefresh),
            );
          }

          final metal = metals[index - 1];
          final sheetKg = stock[metal.sheet] ?? 0;
          final circleKg = stock[metal.circle] ?? 0;
          final total = sheetKg + circleKg; // SS total = sheet + circle
          final isLow =
              lowStockThreshold > 0 && total >= 0 && total < lowStockThreshold;

          // Sheet and Circle are only a way of tagging what came in — the
          // stock that matters is the metal total.
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isLow ? Colors.red.shade50 : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Color(0xFF1F4E79), size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metal.displayName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          isLow
                              ? 'Low stock'
                              : (total < 0 ? 'Deficit' : 'total in stock'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                isLow ? FontWeight.bold : FontWeight.normal,
                            color: isLow || total < 0
                                ? Colors.red
                                : Colors.grey.shade500,
                          ),
                        ),
                      ]),
                ),
                Text(
                  '${total.toStringAsFixed(2)} kg',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: total >= 0 ? Colors.green.shade700 : Colors.red,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sheet / Wastage — one compact button, with the scrap waiting to be sold.
// Loads its own totals so the Inventory tab keeps its simple signature.
// ══════════════════════════════════════════════════════════════════════════════
class _SheetWastageButton extends StatefulWidget {
  final VoidCallback onReturn;
  const _SheetWastageButton({required this.onReturn});

  @override
  State<_SheetWastageButton> createState() => _SheetWastageButtonState();
}

class _SheetWastageButtonState extends State<_SheetWastageButton> {
  double? _wastage;

  @override
  void initState() {
    super.initState();
    _loadWastage();
  }

  Future<void> _loadWastage() async {
    try {
      final svc = FirebaseService.instance;
      final r = await Future.wait([
        svc.getPattaraiStockTxs(),
        svc.getWastageSales(),
      ]);
      if (!mounted) return;
      setState(() => _wastage = wastageInStore(
            r[0] as List<PattaraiStockTx>,
            r[1] as List<WastageSale>,
          ));
    } catch (_) {
      if (mounted) setState(() => _wastage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _wastage;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PattaraiStockScreen()),
        );
        widget.onReturn(); // wastage may have changed company stock
        _loadWastage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F1FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBD5EC)),
        ),
        child: Row(children: [
          const Icon(Icons.compare_arrows, color: Color(0xFF1F4E79), size: 20),
          const SizedBox(width: 10),
          const Text('Sheet / Wastage',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1F4E79))),
          const Spacer(),
          if (w != null && w.abs() > 0.001)
            Text('Wastage ${w.toStringAsFixed(2)} kg',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB3261E))),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: Color(0xFF1F4E79), size: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Transactions Tab — with Edit & Delete
// ══════════════════════════════════════════════════════════════════════════════
class _TransactionsTab extends StatelessWidget {
  final NumberFormat fmt;
  final VoidCallback onRefresh;
  const _TransactionsTab({required this.fmt, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService.instance;
    return StreamBuilder<List<RawMaterialTransaction>>(
      stream: svc.rawMaterialTransactionsStream(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final txs = snap.data ?? [];
        if (txs.isEmpty) {
          return const Center(
              child: Text('No transactions yet.\nGo to Inventory tab and tap + to add.'));
        }
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: txs.length,
            itemBuilder: (_, i) {
              final tx = txs[i];
              final isPurchase = tx.transactionType == 'purchase';
              final color = isPurchase ? Colors.green : Colors.orange;
              final prefix = isPurchase ? '+' : '-';
              // who supplied / sold
                      final partyLabel = tx.supplierName != null && tx.supplierName!.isNotEmpty
                          ? tx.supplierName!
                          : 'Company';
                      return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left icon
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          isPurchase ? Icons.add_shopping_cart : Icons.sell,
                          color: color,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Main info — takes all remaining space
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Material name + date
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    tx.materialType.displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy').format(tx.date),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            // qty @ rate
                            Text(
                              '${tx.quantityKg.toStringAsFixed(2)} kg  @  ₹${fmt.format(tx.ratePerKg)}/kg',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 2),
                            // Party / Company label
                            Row(
                              children: [
                                Icon(
                                  tx.supplierName != null && tx.supplierName!.isNotEmpty
                                      ? Icons.person_outline
                                      : Icons.factory_outlined,
                                  size: 13,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  partyLabel,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                                if (tx.isCredit) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Credit',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.red)),
                                  ),
                                ],
                              ],
                            ),
                            if (tx.isCredit && tx.creditAmount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Due: ₹${fmt.format(tx.creditAmount)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: amount + action buttons
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$prefix ₹${fmt.format(tx.totalValue)}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: color),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _showEditSheet(
                                    context, tx, fmt, onRefresh),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.edit_outlined,
                                      size: 18,
                                      color: Color(0xFF1F4E79)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () =>
                                    _confirmDelete(context, tx, onRefresh),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Secure delete confirmation ─────────────────────────────────────────────
  static Future<void> _confirmDelete(
    BuildContext context,
    RawMaterialTransaction tx,
    VoidCallback onRefresh,
  ) async {
    // Work out what will actually move BEFORE asking, so the owner sees the
    // exact effect on stock and on the party balance.
    List<String> effects;
    try {
      effects = await FirebaseService.instance.describeDeleteEffects(tx);
    } catch (e) {
      effects = ['Could not check the balances: $e'];
    }
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tx.transactionType[0].toUpperCase()}${tx.transactionType.substring(1)}'
              ' — ${tx.quantityKg.toStringAsFixed(2)} kg '
              '${tx.materialType.displayName}\n'
              '${DateFormat('dd MMM yyyy').format(tx.date)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            const Text('This will:',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            ...effects.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 13)),
                      Expanded(
                          child: Text(e,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.35))),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            const Text('This cannot be undone.',
                style: TextStyle(fontSize: 12, color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await FirebaseService.instance.deleteRawMaterialTransaction(tx.id!);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted — stock and balances updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  // ── Edit bottom sheet ──────────────────────────────────────────────────────
  static void _showEditSheet(
    BuildContext context,
    RawMaterialTransaction tx,
    NumberFormat fmt,
    VoidCallback onRefresh,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTransactionSheet(
        transaction: tx,
        fmt: fmt,
        onSaved: onRefresh,
      ),
    );
  }
}

// ── Edit Transaction Sheet ─────────────────────────────────────────────────
class _EditTransactionSheet extends StatefulWidget {
  final RawMaterialTransaction transaction;
  final NumberFormat fmt;
  final VoidCallback onSaved;
  const _EditTransactionSheet({
    required this.transaction,
    required this.fmt,
    required this.onSaved,
  });

  @override
  State<_EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<_EditTransactionSheet> {
  final _svc = FirebaseService.instance;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _qtyCtrl = TextEditingController(text: tx.quantityKg.toStringAsFixed(2));
    _rateCtrl = TextEditingController(text: tx.ratePerKg.toStringAsFixed(2));
    _noteCtrl = TextEditingController(text: tx.note ?? '');
    _date = tx.date;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text);
    final rate = double.tryParse(_rateCtrl.text);
    if (qty == null || rate == null || qty <= 0 || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid quantity and rate')));
      return;
    }

    // ── Secure save confirmation ──────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Save Changes?'),
        content: const Text(
          'Editing this transaction will update the stored values.\n'
          'Note: Party stock and credit balances are not automatically\n'
          'recalculated — adjust them manually if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      final tx = widget.transaction;
      await _svc.updateRawMaterialTransaction(tx.id!, {
        'quantityKg': qty,
        'ratePerKg': rate,
        'totalValue': qty * rate,
        'date': _date.toIso8601String().substring(0, 10),
        'note': _noteCtrl.text,
      });
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction updated')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF1F4E79)),
              const SizedBox(width: 8),
              Text(
                'Edit ${tx.transactionType == 'purchase' ? 'Purchase' : 'Sale'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Read-only info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${tx.materialType.displayName}'
              '${tx.supplierName != null ? '  •  ${tx.supplierName}' : ''}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _qtyCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Rate (₹/kg)', prefixText: '₹ '),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79)),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Parties Tab — with Company Balance card at top
// ══════════════════════════════════════════════════════════════════════════════
class _PartiesTab extends StatefulWidget {
  final NumberFormat fmt;
  final VoidCallback onRefresh;

  /// Bumped by the parent whenever stock changes. This tab keeps its own
  /// cached balances, so without it a delete on another tab would leave the
  /// old kg on screen until a manual pull-to-refresh.
  final int dataVersion;

  const _PartiesTab({
    required this.fmt,
    required this.onRefresh,
    this.dataVersion = 0,
  });

  @override
  State<_PartiesTab> createState() => _PartiesTabState();
}

class _PartiesTabState extends State<_PartiesTab> {
  final _svc = FirebaseService.instance;
  List<PartyStock> _parties = [];
  Map<RawMaterialType, double> _companyStock = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant _PartiesTab old) {
    super.didUpdateWidget(old);
    // Stock changed elsewhere (e.g. a transaction was deleted) — re-read the
    // party balances so this tab never shows kg that no longer exist.
    if (old.dataVersion != widget.dataVersion) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _svc.getAllPartyStock(),
      _svc.getCurrentStock(), // company-only stock
    ]);
    if (!mounted) return;
    setState(() {
      _parties = results[0] as List<PartyStock>;
      _companyStock = results[1] as Map<RawMaterialType, double>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: () async {
        await _loadData();
        widget.onRefresh();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Total stock card ──────────────────────────────────────────────
          _CompanyBalanceCard(
              stock: _companyStock, parties: _parties, fmt: widget.fmt),
          const SizedBox(height: 14),

          if (_parties.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'No raw material stock recorded for any party.\nAdd a purchase and select a party.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            const Text(
              'Party Balances',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            // Compact rows: party name, what they hold in total, and the
            // per-metal split on one line. No expand/collapse needed.
            ...List.generate(_parties.length, (i) {
              final party = _parties[i];
              final isSupplier = party.partyType == 'supplier';
              final color = isSupplier
                  ? const Color(0xFF1F4E79)
                  : const Color(0xFF7B4F06);

              // Total this party holds (negative entries mean they owe sheet).
              final total =
                  party.stock.values.fold<double>(0, (s, v) => s + v);

              // "SS 200 · Brass 40" — only the metals they actually hold.
              final parts = <String>[];
              for (final metal in MaterialMetal.values) {
                final kg = (party.stock[metal.sheet] ?? 0) +
                    (party.stock[metal.circle] ?? 0);
                if (kg.abs() >= 0.01) {
                  parts.add('${metal.displayName} ${kg.toStringAsFixed(2)}');
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(isSupplier ? Icons.business : Icons.person,
                      color: color, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(party.partyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13.5)),
                          if (parts.isNotEmpty)
                            Text(parts.join('  ·  '),
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.grey.shade600)),
                        ]),
                  ),
                  Text(
                    total < 0
                        ? 'Owes ${(-total).toStringAsFixed(2)} kg'
                        : '${total.toStringAsFixed(2)} kg',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: total < 0 ? Colors.red : Colors.green.shade700,
                    ),
                  ),
                ]),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Total stock card ───────────────────────────────────────────────────────
// Company sheet PLUS what the parties are holding, so the number here matches
// the Inventory tab. Showing company-only here was misleading: sheet a party
// gave us is ours, and it does count toward total stock.
class _CompanyBalanceCard extends StatelessWidget {
  final Map<RawMaterialType, double> stock; // company only
  final List<PartyStock> parties;
  final NumberFormat fmt;
  const _CompanyBalanceCard({
    required this.stock,
    required this.parties,
    required this.fmt,
  });

  /// Positive party holdings for one metal — the same rule getTotalStock uses.
  double _withParties(MaterialMetal metal) {
    double kg = 0;
    for (final p in parties) {
      for (final t in [metal.sheet, metal.circle]) {
        final v = p.stock[t] ?? 0;
        if (v > 0) kg += v;
      }
    }
    return kg;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    for (final metal in MaterialMetal.values) {
      final company = (stock[metal.sheet] ?? 0) + (stock[metal.circle] ?? 0);
      final party = _withParties(metal);
      final total = company + party;
      if (company.abs() < 0.01 && party.abs() < 0.01) continue; // keep it short

      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
            width: 56,
            child: Text(metal.displayName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: party > 0.01
                ? Text('company ${company.toStringAsFixed(2)}  •  '
                    'party ${party.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10.5))
                : const SizedBox.shrink(),
          ),
          Text('${total.toStringAsFixed(2)} kg',
              style: TextStyle(
                color: total < 0 ? Colors.red.shade300 : Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
        ]),
      ));
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4E79),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 16),
          SizedBox(width: 7),
          Text('Total stock',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5)),
          Spacer(),
          Text('company + party',
              style: TextStyle(color: Colors.white38, fontSize: 10.5)),
        ]),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('No stock recorded yet.',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          )
        else
          ...rows,
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Add Transaction Bottom Sheet (unchanged)
// ══════════════════════════════════════════════════════════════════════════════
class _AddMaterialTransactionSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddMaterialTransactionSheet({required this.onSaved});

  @override
  State<_AddMaterialTransactionSheet> createState() =>
      _AddMaterialTransactionSheetState();
}

class _AddMaterialTransactionSheetState
    extends State<_AddMaterialTransactionSheet> {
  final _svc = FirebaseService.instance;

  // Material is picked in two steps: metal first, then the form it came in.
  MaterialMetal _metal = MaterialMetal.ss;
  bool _isSheet = true;
  RawMaterialType get _material => _metal.form(isSheet: _isSheet);

  String _type = 'purchase';
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  bool _isCompanyPurchase = true;
  String? _supplierId;
  String _supplierName = '';
  String? _supplierType;
  bool _isCredit = false;
  final _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _parties = [];
  AppSettings _appSettings = const AppSettings();

  // Optional: send this purchase straight out to a pattarai. null = keep it
  // in the company store.
  List<Pattarai> _pattarais = [];
  String? _sendToPattaraiId;

  @override
  void initState() {
    super.initState();
    _loadParties();
    _loadDefaultRate();
    _loadPattarais();
  }

  Future<void> _loadPattarais() async {
    try {
      final list = await _svc.getPattarais();
      if (mounted) setState(() => _pattarais = list);
    } catch (_) {
      // Offline — the purchase still saves, just without the hand-off.
    }
  }

  Future<void> _loadDefaultRate() async {
    final s = await _svc.getAppSettings();
    setState(() {
      _appSettings = s;
      _applyDefaultRate();
    });
  }

  void _applyDefaultRate() {
    if (_rateCtrl.text.isNotEmpty) return;
    final v = _appSettings.defaultRatesPerKg[_material.displayName];
    if (v != null && v > 0) _rateCtrl.text = v.toStringAsFixed(0);
  }

  Future<void> _loadParties() async {
    final suppliers = await _svc.getSuppliers();
    final buyers = await _svc.getBuyers();
    final List<Map<String, dynamic>> list = [];
    for (var s in suppliers) list.add({'id': s.id, 'name': s.name, 'type': 'supplier'});
    for (var b in buyers) list.add({'id': b.id, 'name': b.name, 'type': 'buyer'});
    setState(() => _parties = list);
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text);
    final rate = double.tryParse(_rateCtrl.text);
    if (qty == null || rate == null || qty <= 0 || rate <= 0) return;

    if (_type == 'purchase' &&
        !_isCompanyPurchase &&
        (_supplierId == null || _supplierName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select who gave the sheet (buyer or supplier)')));
      return;
    }

    final tx = RawMaterialTransaction(
      materialType: _material,
      date: _date,
      quantityKg: qty,
      ratePerKg: rate,
      transactionType: _type,
      supplierId: _isCompanyPurchase ? null : _supplierId,
      supplierName: _isCompanyPurchase ? null : _supplierName,
      isCredit: _type == 'purchase' && !_isCompanyPurchase && _isCredit,
      creditAmount:
          _type == 'purchase' && !_isCompanyPurchase && _isCredit ? qty * rate : 0,
      note: _noteCtrl.text,
    );
    await _svc.addRawMaterialTransaction(tx,
        partyType: _isCompanyPurchase ? null : _supplierType);

    // Hand it straight to a pattarai if one was picked. This does not change
    // company stock — it only opens the pattarai's account for this sheet,
    // exactly as "Send sheet" does on the Sheet / Wastage screen.
    if (_type == 'purchase' && _sendToPattaraiId != null) {
      final p = _pattarais.firstWhere(
        (x) => (x.id ?? x.name) == _sendToPattaraiId,
        orElse: () => _pattarais.first,
      );
      await _svc.addPattaraiStockTx(PattaraiStockTx(
        pattaraiId: p.id ?? p.name,
        pattaraiName: p.name,
        type: PattaraiTxType.issue,
        materialType: _material,
        quantityKg: qty,
        date: _date,
        note: 'From purchase',
      ));
    }

    widget.onSaved();
    if (mounted) {
      // The party actually chosen on this purchase.
      final partyName = _isCompanyPurchase ? null : _supplierName;
      final isPurchase = _type == 'purchase';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      AppToast.showWith(
        messenger,
        isPurchase ? ToastEvent.purchase : ToastEvent.saved,
        name: partyName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Add ${_type == 'purchase' ? 'Purchase' : 'Sale'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // ── Material: metal first, then the form it came in ──────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Material',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            for (final m in MaterialMetal.values) ...[
              Expanded(
                child: _buildMetalButton(m),
              ),
              if (m != MaterialMetal.values.last) const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Sheet or Circle?',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: _buildFormButton(
                    isSheet: true, icon: Icons.article_outlined, label: 'Sheet')),
            const SizedBox(width: 8),
            Expanded(
                child: _buildFormButton(
                    isSheet: false,
                    icon: Icons.layers_outlined,
                    label: 'Circle')),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Saving as: ${_material.displayName}',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F4E79))),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildTypeButton('purchase', Icons.shopping_cart, 'Purchase')),
            const SizedBox(width: 12),
            Expanded(child: _buildTypeButton('sale', Icons.sell, 'Sale')),
          ]),
          const SizedBox(height: 12),
          TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity (kg)')),
          const SizedBox(height: 12),
          TextField(
              controller: _rateCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Rate (₹/kg)', prefixText: '₹ ')),

          // ── Optional hand-off straight to a pattarai ────────────────────
          if (_type == 'purchase' && _pattarais.isNotEmpty) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: _sendToPattaraiId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Send to pattarai (optional)',
                helperText: 'Company stock stays the same — it just opens '
                    'the pattarai\'s account',
                helperMaxLines: 2,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Keep in company store'),
                ),
                ..._pattarais.map((p) => DropdownMenuItem<String?>(
                      value: p.id ?? p.name,
                      child: Text(p.name),
                    )),
              ],
              onChanged: (v) => setState(() => _sendToPattaraiId = v),
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.calendar_today),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (_type == 'purchase') ...[
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Who gave the sheet?',
                    style: TextStyle(fontWeight: FontWeight.w600))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _buildSourceButton(true, Icons.factory, 'Company (mine)')),
              const SizedBox(width: 12),
              Expanded(child: _buildSourceButton(false, Icons.handshake, 'Party')),
            ]),
            const SizedBox(height: 12),
            if (!_isCompanyPurchase) ...[
              DropdownButtonFormField<String>(
                value: _supplierId,
                hint: const Text('Select buyer or supplier'),
                isExpanded: true,
                items: _parties
                    .map((p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(
                            '${p['name']} (${p['type'] == 'supplier' ? 'Supplier' : 'Buyer'})')))
                    .toList(),
                onChanged: (id) {
                  if (id == null) return;
                  final party = _parties.firstWhere((p) => p['id'] == id);
                  setState(() {
                    _supplierId = id;
                    _supplierName = party['name'];
                    _supplierType = party['type'];
                    if (_supplierType != 'supplier') _isCredit = false;
                  });
                },
                decoration: const InputDecoration(labelText: 'Party'),
              ),
              if (_supplierId != null && _supplierType == 'supplier')
                SwitchListTile(
                  title: const Text('Purchase on credit'),
                  value: _isCredit,
                  onChanged: (v) => setState(() => _isCredit = v),
                ),
              const SizedBox(height: 4),
            ],
          ],
          TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _save,
              child: Text('Save ${_type == 'purchase' ? 'Purchase' : 'Sale'}'),
            ),
          ),
        ]),
      ),
    );
  }

  /// SS / BRASS / COPPER
  Widget _buildMetalButton(MaterialMetal m) {
    final selected = _metal == m;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        _metal = m;
        _rateCtrl.clear();
        _applyDefaultRate();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F4E79) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? const Color(0xFF1F4E79) : Colors.grey.shade300),
        ),
        child: Text(
          m.chipLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  /// Sheet / Circle
  Widget _buildFormButton(
      {required bool isSheet, required IconData icon, required String label}) {
    final selected = _isSheet == isSheet;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        _isSheet = isSheet;
        _rateCtrl.clear();
        _applyDefaultRate();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F1FB) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? const Color(0xFF1F4E79) : Colors.grey.shade300,
              width: selected ? 1.5 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 16,
              color:
                  selected ? const Color(0xFF1F4E79) : Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color:
                    selected ? const Color(0xFF1F4E79) : Colors.grey.shade700,
              )),
        ]),
      ),
    );
  }

  Widget _buildTypeButton(String type, IconData icon, String label) => FilterChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ]),
        selected: _type == type,
        onSelected: (_) => setState(() => _type = type),
      );

  Widget _buildSourceButton(bool isCompany, IconData icon, String label) {
    final selected = _isCompanyPurchase == isCompany;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() {
        _isCompanyPurchase = isCompany;
        if (isCompany) {
          _supplierId = null;
          _supplierName = '';
          _supplierType = null;
          _isCredit = false;
        }
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1F4E79) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF1F4E79) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : Colors.grey.shade700),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}