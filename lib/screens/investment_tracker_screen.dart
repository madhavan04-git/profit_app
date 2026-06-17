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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStock();
  }

  // UPDATED: use getTotalStock() to include party stocks
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
          _InventoryTab(stock: _stock, loading: _loadingStock, fmt: _fmt, onRefresh: _loadStock),
          _TransactionsTab(fmt: _fmt, onRefresh: _loadStock),
          _PartiesTab(fmt: _fmt, onRefresh: _loadStock),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Add Purchase/Sale'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
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

// ------------------ Inventory Tab (unchanged) ------------------
class _InventoryTab extends StatelessWidget {
  final Map<RawMaterialType, double> stock;
  final bool loading;
  final NumberFormat fmt;
  final VoidCallback onRefresh;

  const _InventoryTab({required this.stock, required this.loading, required this.fmt, required this.onRefresh});

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
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: type.isSheet ? const Color(0xFFE6F1FB) : const Color(0xFFFAEEDA),
                child: Icon(type.isSheet ? Icons.article : Icons.circle, color: const Color(0xFF1F4E79)),
              ),
              title: Text(type.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${kg.toStringAsFixed(2)} kg', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kg >= 0 ? Colors.green.shade700 : Colors.red)),
              trailing: Text('in stock', style: TextStyle(color: Colors.grey.shade500)),
            ),
          );
        },
      ),
    );
  }
}

// ------------------ Transactions Tab (unchanged) ------------------
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
          return const Center(child: Text('No transactions yet.\nTap + to add purchase or sale.'));
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
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(isPurchase ? Icons.add_shopping_cart : Icons.sell, color: color),
                  title: Text('${tx.materialType.displayName}  •  ${DateFormat('dd MMM yyyy').format(tx.date)}'),
                  subtitle: Text('${tx.quantityKg.toStringAsFixed(2)} kg @ ₹${fmt.format(tx.ratePerKg)}/kg\n${tx.supplierName ?? ''} ${tx.isCredit ? '(Credit)' : ''}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$prefix ₹${fmt.format(tx.totalValue)}', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                    if (tx.isCredit && tx.creditAmount > 0)
                      Text('Due: ₹${fmt.format(tx.creditAmount)}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ]),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ------------------ Parties Tab (unchanged) ------------------
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    setState(() => _loading = true);
    final snapshot = await _svc.getAllPartyStock();
    setState(() {
      _parties = snapshot;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_parties.isEmpty) {
      return const Center(child: Text('No raw material stock recorded for any party.\nAdd a purchase and select a party.'));
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadParties();
        widget.onRefresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _parties.length,
        itemBuilder: (_, i) {
          final party = _parties[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Row(children: [
                Icon(party.partyType == 'supplier' ? Icons.business : Icons.person,
                    color: party.partyType == 'supplier' ? const Color(0xFF1F4E79) : const Color(0xFF7B4F06)),
                const SizedBox(width: 8),
                Expanded(child: Text(party.partyName, style: const TextStyle(fontWeight: FontWeight.bold))),
              ]),
              subtitle: Text(party.partyType == 'supplier' ? 'Supplier' : 'Buyer (also supplies)'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: party.stock.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key.displayName, style: const TextStyle(fontSize: 13)),
                            Text('${entry.value.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ------------------ Add Transaction Bottom Sheet (unchanged) ------------------
class _AddMaterialTransactionSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _AddMaterialTransactionSheet({required this.onSaved});

  @override
  State<_AddMaterialTransactionSheet> createState() => _AddMaterialTransactionSheetState();
}

class _AddMaterialTransactionSheetState extends State<_AddMaterialTransactionSheet> {
  final _svc = FirebaseService.instance;
  RawMaterialType _material = RawMaterialType.ssSheet;
  String _type = 'purchase';
  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String? _supplierId;
  String _supplierName = '';
  bool _isCredit = false;
  final _noteCtrl = TextEditingController();

  List<Map<String, dynamic>> _parties = [];

  @override
  void initState() {
    super.initState();
    _loadParties();
  }

  Future<void> _loadParties() async {
    final suppliers = await _svc.getSuppliers();
    final buyers = await _svc.getBuyers();
    final List<Map<String, dynamic>> list = [];
    for (var s in suppliers) {
      list.add({'id': s.id, 'name': s.name, 'type': 'supplier'});
    }
    for (var b in buyers) {
      list.add({'id': b.id, 'name': b.name, 'type': 'buyer'});
    }
    setState(() => _parties = list);
  }

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text);
    final rate = double.tryParse(_rateCtrl.text);
    if (qty == null || rate == null || qty <= 0 || rate <= 0) return;

    // For purchases only, we require a party
    if (_type == 'purchase' && (_supplierId == null || _supplierName.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a supplier or buyer for this purchase')));
      return;
    }

    final tx = RawMaterialTransaction(
      materialType: _material,
      date: _date,
      quantityKg: qty,
      ratePerKg: rate,
      transactionType: _type,
      supplierId: _supplierId,
      supplierName: _supplierName,
      isCredit: _type == 'purchase' && _isCredit,
      creditAmount: _type == 'purchase' && _isCredit ? qty * rate : 0,
      note: _noteCtrl.text,
    );
    // addRawMaterialTransaction already updates party stock internally
    await _svc.addRawMaterialTransaction(tx);

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Add ${_type == 'purchase' ? 'Purchase' : 'Sale'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<RawMaterialType>(
            value: _material,
            items: RawMaterialType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.displayName))).toList(),
            onChanged: (v) => setState(() => _material = v!),
            decoration: const InputDecoration(labelText: 'Material'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildTypeButton('purchase', Icons.shopping_cart, 'Purchase')),
            const SizedBox(width: 12),
            Expanded(child: _buildTypeButton('sale', Icons.sell, 'Sale')),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity (kg)')),
          const SizedBox(height: 12),
          TextField(controller: _rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rate (₹/kg)', prefixText: '₹ ')),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (d != null) setState(() => _date = d);
            },
            child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [const Icon(Icons.calendar_today), const SizedBox(width: 8), Text(DateFormat('dd MMM yyyy').format(_date))]),
            ),
          ),
          const SizedBox(height: 12),
          if (_type == 'purchase')
            DropdownButtonFormField<String>(
              value: _supplierId,
              hint: const Text('Select supplier or buyer'),
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('No party')),
                ..._parties.map((p) => DropdownMenuItem(value: p['id'], child: Text('${p['name']} (${p['type'] == 'supplier' ? 'Supplier' : 'Buyer'})'))),
              ],
              onChanged: (id) {
                if (id == null) {
                  setState(() {
                    _supplierId = null;
                    _supplierName = '';
                    _isCredit = false;
                  });
                } else {
                  final party = _parties.firstWhere((p) => p['id'] == id);
                  setState(() {
                    _supplierId = id;
                    _supplierName = party['name'];
                    if (party['type'] != 'supplier') _isCredit = false;
                  });
                }
              },
              decoration: const InputDecoration(labelText: 'Party (Supplier/Buyer)'),
            ),
          if (_type == 'purchase' && _supplierId != null && _parties.firstWhere((p) => p['id'] == _supplierId)['type'] == 'supplier')
            SwitchListTile(
              title: const Text('Purchase on credit'),
              value: _isCredit,
              onChanged: (v) => setState(() => _isCredit = v),
            ),
          TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(onPressed: _save, child: Text('Save ${_type == 'purchase' ? 'Purchase' : 'Sale'}'))),
        ]),
      ),
    );
  }

  Widget _buildTypeButton(String type, IconData icon, String label) => FilterChip(
    label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)]),
    selected: _type == type,
    onSelected: (_) => setState(() => _type = type),
  );
}