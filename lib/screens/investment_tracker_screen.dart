// lib/screens/investment_tracker_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

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
          _PartiesTab(fmt: _fmt, onRefresh: _loadStock),
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
    final materials = RawMaterialType.values;
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: materials.length,
        itemBuilder: (_, i) {
          final type = materials[i];
          final kg = stock[type] ?? 0;
          final isLow = lowStockThreshold > 0 && kg >= 0 && kg < lowStockThreshold;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isLow ? Colors.red.shade50 : null,
            child: ListTile(
              leading: Icon(
                type.isSheet ? Icons.article_outlined : Icons.layers_outlined,
                color: const Color(0xFF1F4E79),
                size: 28,
              ),
              title: Text(type.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${kg.toStringAsFixed(2)} kg',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kg >= 0 ? Colors.green.shade700 : Colors.red,
                ),
              ),
              trailing: isLow
                  ? const Text('Low stock',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold))
                  : Text(
                      kg < 0 ? 'Deficit' : 'in stock',
                      style: TextStyle(
                          color: kg < 0 ? Colors.red : Colors.grey.shade500),
                    ),
            ),
          );
        },
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text(
          'This will permanently delete the ${tx.transactionType} of '
          '${tx.quantityKg.toStringAsFixed(2)} kg ${tx.materialType.displayName} '
          'on ${DateFormat('dd MMM yyyy').format(tx.date)}.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseService.instance.deleteRawMaterialTransaction(tx.id!);
      onRefresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
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
  const _PartiesTab({required this.fmt, required this.onRefresh});

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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _svc.getAllPartyStock(),
      _svc.getCurrentStock(), // company-only stock
    ]);
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
          // ── Company Balance Card ──────────────────────────────────────────
          _CompanyBalanceCard(stock: _companyStock, fmt: widget.fmt),
          const SizedBox(height: 16),

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
            ...List.generate(_parties.length, (i) {
              final party = _parties[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Row(children: [
                    Icon(
                      party.partyType == 'supplier' ? Icons.business : Icons.person,
                      color: party.partyType == 'supplier'
                          ? const Color(0xFF1F4E79)
                          : const Color(0xFF7B4F06),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(party.partyName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  subtitle:
                      Text(party.partyType == 'supplier' ? 'Supplier' : 'Buyer (also supplies)'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: party.stock.entries.map((entry) {
                          final value = entry.value;
                          final isDebt = value < 0;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key.displayName,
                                    style: const TextStyle(fontSize: 13)),
                                Text(
                                  isDebt
                                      ? 'Owes ${(-value).toStringAsFixed(2)} kg'
                                      : '${value.toStringAsFixed(2)} kg',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDebt ? Colors.red : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── Company Balance Card widget ────────────────────────────────────────────
class _CompanyBalanceCard extends StatelessWidget {
  final Map<RawMaterialType, double> stock;
  final NumberFormat fmt;
  const _CompanyBalanceCard({required this.stock, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1F4E79),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.factory, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Company Balance',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ]),
            const SizedBox(height: 12),
            if (stock.isEmpty)
              const Text('No company stock recorded.',
                  style: TextStyle(color: Colors.white70))
            else
              ...RawMaterialType.values.map((type) {
                final kg = stock[type] ?? 0;
                final isLow = kg < 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        type.displayName,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '${kg.toStringAsFixed(2)} kg',
                        style: TextStyle(
                          color: isLow ? Colors.red.shade300 : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
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
  RawMaterialType _material = RawMaterialType.ssSheet;
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

  @override
  void initState() {
    super.initState();
    _loadParties();
    _loadDefaultRate();
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

    widget.onSaved();
    if (mounted) Navigator.pop(context);
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
          DropdownButtonFormField<RawMaterialType>(
            value: _material,
            items: RawMaterialType.values
                .map((e) => DropdownMenuItem(value: e, child: Text(e.displayName)))
                .toList(),
            onChanged: (v) => setState(() {
              _material = v!;
              _rateCtrl.clear();
              _applyDefaultRate();
            }),
            decoration: const InputDecoration(labelText: 'Material'),
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