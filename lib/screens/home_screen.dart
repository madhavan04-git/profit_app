// lib/screens/home_screen.dart - Complete with Worker Override Feature

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'monthly_screen.dart';
import 'buyers_screen.dart';
import 'workers_screen.dart';
import 'expenses_screen.dart';
import 'products_screen.dart';
import 'buyer_transactions_screen.dart';
import 'worker_transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _svc          = FirebaseService.instance;
  final _scaffoldKey  = GlobalKey<ScaffoldState>();

  DateTime _date       = DateTime.now();
  List<Sale>    _sales    = [];
  List<Product> _products = [];
  List<Buyer>   _buyers   = [];
  List<Worker>  _workers  = [];
  double _dayProfit    = 0;
  double _monthProfit  = 0;
  bool   _loading      = true;
  int    _navIndex     = 0;   // 0=Home 1=Buyers 2=Workers 3=Expenses

  @override
  void initState() { super.initState(); _loadAll(); }

  // ── Data loading ─────────────────────────────────────────────────────────────
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _svc.getProducts(),
      _svc.getBuyers(),
      _svc.getWorkers(),
      _svc.salesForDate(_date),
      _svc.monthlyTotalProfit(_date.year, _date.month),
    ]);
    final sales = results[3] as List<Sale>;
    setState(() {
      _products    = results[0] as List<Product>;
      _buyers      = results[1] as List<Buyer>;
      _workers     = results[2] as List<Worker>;
      _sales       = sales;
      _dayProfit   = sales.fold(0, (s, x) => s + x.profit);
      _monthProfit = results[4] as double;
      _loading     = false;
    });
  }

  Future<void> _reloadSales() async {
    final results = await Future.wait([
      _svc.salesForDate(_date),
      _svc.monthlyTotalProfit(_date.year, _date.month),
    ]);
    final sales = results[0] as List<Sale>;
    setState(() {
      _sales       = sales;
      _dayProfit   = sales.fold(0, (s, x) => s + x.profit);
      _monthProfit = results[1] as double;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context, initialDate: _date,
        firstDate: DateTime(2024), lastDate: DateTime.now());
    if (d != null) { setState(() => _date = d); _reloadSales(); }
  }

  void _addSale() {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSaleSheet(
        date: _date, products: _products, buyers: _buyers,
        onSaved: _reloadSales,
      ),
    );
  }

  Future<void> _deleteSale(Sale sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text('Delete ${sale.productName} — Rs ${sale.profit.toStringAsFixed(2)} profit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) { await _svc.deleteSale(sale.id!); _reloadSales(); }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to logout from My Pattarii?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ));
    if (ok == true) await _svc.logout();
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildSidebar(),
      body: _navIndex == 0 ? _buildHome()
          : _navIndex == 1 ? const BuyersScreen()
          : _navIndex == 2 ? const WorkersScreen()
          : const ExpensesScreen(),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _addSale,
              icon: const Icon(Icons.add),
              label: const Text('Add Sale', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white)
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() => _navIndex = i),
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people), label: 'Buyers'),
          NavigationDestination(icon: Icon(Icons.engineering_outlined),
              selectedIcon: Icon(Icons.engineering), label: 'Workers'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long), label: 'Expenses'),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SIDEBAR DRAWER — opens when logo is tapped
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    final user = _svc.currentUser;
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1F4E79), Color(0xFF2E6FA8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/icon/logo4.png',
                    width: 56, height: 56, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.store, color: Colors.white, size: 30),
                    )),
              ),
              const SizedBox(height: 12),
              Text('My Pattarii',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(user?.displayName ?? user?.email ?? '',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
            ]),
          ),

          const SizedBox(height: 8),

          // ── Navigation items ──────────────────────────────────────
          _sideItem(Icons.home, 'Home', () {
            Navigator.pop(context);
            setState(() => _navIndex = 0);
          }, selected: _navIndex == 0),

          _sideItem(Icons.people, 'Buyers', () {
            Navigator.pop(context);
            setState(() => _navIndex = 1);
          }, selected: _navIndex == 1),

          _sideItem(Icons.engineering, 'Workers', () {
            Navigator.pop(context);
            setState(() => _navIndex = 2);
          }, selected: _navIndex == 2),

          _sideItem(Icons.receipt_long, 'Expenses', () {
            Navigator.pop(context);
            setState(() => _navIndex = 3);
          }, selected: _navIndex == 3),

          const Divider(height: 24, indent: 16, endIndent: 16),

          _sideItem(Icons.inventory_2_outlined, 'Products', () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProductsScreen()))
                .then((_) => _loadAll());
          }),

          _sideItem(Icons.bar_chart_rounded, 'Monthly Report', () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const MonthlyScreen()))
                .then((_) => _reloadSales());
          }),

          _sideItem(Icons.account_balance_wallet_outlined, 'Buyer Transactions', () {
            Navigator.pop(context);
            Navigator.push(context, 
                MaterialPageRoute(builder: (_) => const BuyerTransactionsScreen()));
          }),

          _sideItem(Icons.payments_outlined, 'Worker Transactions', () {
            Navigator.pop(context);
            Navigator.push(context, 
                MaterialPageRoute(builder: (_) => const WorkerTransactionsScreen()));
          }),

          const Spacer(),
          const Divider(height: 1, indent: 16, endIndent: 16),

          _sideItem(Icons.logout, 'Logout', () {
            Navigator.pop(context);
            _confirmLogout();
          }, color: Colors.red.shade400),

          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _sideItem(IconData icon, String label, VoidCallback onTap,
      {bool selected = false, Color? color}) {
    final c = color ?? (selected ? const Color(0xFF1F4E79) : const Color(0xFF444444));
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE6F1FB) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 14, fontWeight:
              selected ? FontWeight.w700 : FontWeight.w500, color: c)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // HOME BODY
  // ══════════════════════════════════════════════════════════════════════════════
  Widget _buildHome() {
    final fmt = NumberFormat('#,##0', 'en_IN');
    final user = _svc.currentUser;
    final top  = MediaQuery.of(context).padding.top;

    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, top + 10, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // ★ Logo — tap to open sidebar ★
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/icon/logo4.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1F4E79),
                        child: const Icon(Icons.store, color: Colors.white, size: 24),
                      )),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.displayName?.split(' ').first ?? 'there'}!',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              Text(DateUtils.isSameDay(_date, DateTime.now())
                  ? 'Today — ${DateFormat('dd MMM yyyy').format(_date)}'
                  : DateFormat('EEEE, dd MMM yyyy').format(_date),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ]),
            const Spacer(),
          ]),
          const SizedBox(height: 12),

          // ── Profit summary cards ───────────────────────────────────
          Row(children: [
            Expanded(child: _miniCard('Today',
                'Rs ${fmt.format(_dayProfit)}',
                const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
            const SizedBox(width: 10),
            Expanded(child: _miniCard('This Month',
                'Rs ${fmt.format(_monthProfit)}',
                const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(10)),
                child: const Column(children: [
                  Icon(Icons.calendar_today, size: 18, color: Color(0xFF1F4E79)),
                  SizedBox(height: 3),
                  Text('Date', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ]),
              ),
            ),
          ]),
        ]),
      ),

      // ── Scrollable body ───────────────────────────────────────────────────
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    _sectionHeader(
                      icon: Icons.receipt_long_outlined,
                      title: "Today's Sales",
                      color: const Color(0xFF7B4F06),
                      onViewAll: null,
                    ),
                    const SizedBox(height: 8),

                    if (_sales.isEmpty)
                      _emptyCard(
                        'No sales for ${DateFormat('dd MMM').format(_date)}',
                        'Tap + Add Sale to record a sale',
                        Icons.receipt_long_outlined,
                      )
                    else
                      ..._sales.map((s) => _SaleCard(sale: s, onDelete: () => _deleteSale(s))),
                  ],
                ),
              ),
      ),
    ]);
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onViewAll,
  }) =>
      Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15,
            fontWeight: FontWeight.bold, color: color)),
        const Spacer(),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('View All', style: TextStyle(fontSize: 12)),
          ),
      ]);

  Widget _emptyCard(String title, String subtitle, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE))),
    child: Row(children: [
      Icon(icon, size: 32, color: Colors.grey.shade300),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w500, color: Colors.grey)),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ]),
  );

  Widget _miniCard(String label, String value, Color textColor, Color bg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
              color: textColor), overflow: TextOverflow.ellipsis),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// SALE CARD
// ══════════════════════════════════════════════════════════════════════════════
class _SaleCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onDelete;
  const _SaleCard({required this.sale, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final s = sale;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: s.productCategory == 'SS'
                ? const Color(0xFFE6F1FB) : const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(s.productCategory,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: s.productCategory == 'SS'
                      ? const Color(0xFF1F4E79) : const Color(0xFF7B4F06)))),
        ),
        title: Text(s.productName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${s.qty % 1 == 0 ? s.qty.toInt() : s.qty.toStringAsFixed(1)} kg'
          '${s.buyerName != null ? '  •  ${s.buyerName}' : ''}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Rs ${fmt.format(s.profit)}',
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 14, color: Color(0xFF1A6B2A))),
          const SizedBox(width: 4),
          IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFCC4444)),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD SALE SHEET - WITH WORKER OVERRIDE
// ══════════════════════════════════════════════════════════════════════════════
class AddSaleSheet extends StatefulWidget {
  final DateTime date;
  final List<Product> products;
  final List<Buyer> buyers;
  final VoidCallback onSaved;
  const AddSaleSheet({super.key, required this.date, required this.products,
      required this.buyers, required this.onSaved});
  @override State<AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<AddSaleSheet> {
  Product? _product;
  Buyer? _buyer;
  final _qty       = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _customPrice = false;
  double _profit = 0, _effectivePrice = 0;
  bool _saving = false;
  
  // Worker override fields
  bool _overrideWorkers = false;
  Map<String, String> _workerOverrides = {}; // originalRole -> newRole
  List<Worker> _workers = [];

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    _workers = await FirebaseService.instance.getWorkers();
    setState(() {});
  }

  void _selectProduct(Product? p) {
    setState(() {
      _product = p;
      _effectivePrice = p?.sellPricePerKg ?? 0;
      _priceCtrl.text = _effectivePrice.toStringAsFixed(0);
      _workerOverrides.clear();
      _overrideWorkers = false;
    });
    _recalc();
  }

  void _recalc() {
    if (_product == null) { setState(() => _profit = 0); return; }
    final qty = double.tryParse(_qty.text) ?? 0;
    final p   = _product!;
    double profit;
    if (_customPrice) {
      final customPricePerKg = double.tryParse(_priceCtrl.text) ?? p.sellPricePerKg;
      _effectivePrice = customPricePerKg;
      final profitPerKg = customPricePerKg - p.costPerKg;
      profit = p.soldByPiece
          ? qty * profitPerKg * (p.productWeightG / 1000.0)
          : qty * profitPerKg;
    } else {
      _effectivePrice = p.sellPricePerKg;
      profit = p.profitForQty(qty);
    }
    setState(() => _profit = profit);
  }

  // Get final worker rates with overrides applied
  Map<String, double> _getFinalWorkerRates() {
    if (_product == null) return {};
    
    final baseRates = Map<String, double>.from(_product!.workerRatesPerKg);
    
    if (!_overrideWorkers || _workerOverrides.isEmpty) {
      return baseRates;
    }
    
    // Apply overrides: transfer earnings from original role to new worker
    final Map<String, double> finalRates = {};
    
    for (final entry in baseRates.entries) {
      final originalRole = entry.key;
      final rate = entry.value;
      
      if (_workerOverrides.containsKey(originalRole)) {
        final newRole = _workerOverrides[originalRole]!;
        finalRates[newRole] = (finalRates[newRole] ?? 0) + rate;
      } else {
        finalRates[originalRole] = (finalRates[originalRole] ?? 0) + rate;
      }
    }
    
    return finalRates;
  }

  Future<void> _save() async {
    if (_product == null || _qty.text.isEmpty) return;
    setState(() => _saving = true);
    final qty = double.tryParse(_qty.text) ?? 0;

    final saleAmount = qty * _effectivePrice;
    
    // Get worker rates with overrides applied
    final finalWorkerRates = _getFinalWorkerRates();
    
    final sale = Sale(
      productId:        _product!.id!,
      productName:      _product!.name,
      productCategory:  _product!.category,
      buyerId:          _buyer?.id,
      buyerName:        _buyer?.name,
      qty:              qty,
      salePrice:        _effectivePrice,
      profit:           _profit,
      date:             widget.date,
      workerRatesPerKg: finalWorkerRates,
    );
    await FirebaseService.instance.addSale(sale);
    
    if (_buyer != null && _buyer!.id != null) {
      final tx = SimpleTransaction(
        buyerId: _buyer!.id!,
        buyerName: _buyer!.name,
        type: SimpleTxType.credit,
        amount: saleAmount,
        note: 'Sale: ${_product!.name} - ${qty} ${_product!.unit}',
        dateTime: widget.date,
      );
      await FirebaseService.instance.addSimpleTransaction(tx);
    }
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt    = NumberFormat('#,##0.00', 'en_IN');

    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Row(children: [
            const Text('Add Sale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(DateFormat('dd MMM yyyy').format(widget.date),
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
          ]),
          const SizedBox(height: 16),

          _DropField<Product>(
            value: _product, hint: 'Select product *',
            items: widget.products,
            label:   (p) => '${p.category} — ${p.name}',
            caption: (p) => 'Rs ${fmt.format(p.profitPerUnit)}/${p.unit}',
            onChanged: _selectProduct,
          ),
          const SizedBox(height: 10),

          if (_product != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFF1F4E79)),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  'Sell: Rs ${_product!.sellPricePerKg.toStringAsFixed(0)}/kg  '
                  '•  Cost: Rs ${fmt.format(_product!.costPerKg)}/kg  '
                  '•  Profit: Rs ${fmt.format(_product!.profitPerUnit)}/${_product!.unit}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1F4E79)))),
              ]),
            ),

          _DropField<Buyer?>(
            value: _buyer, hint: 'Select buyer (optional)',
            items: [null, ...widget.buyers],
            label:   (b) => b == null ? 'No buyer' : b.name,
            caption: (b) => b == null ? '' : b.phone,
            onChanged: (b) => setState(() => _buyer = b),
          ),
          const SizedBox(height: 10),

          // ── Worker Override Section ─────────────────────────────────────────
          if (_product != null && _workers.isNotEmpty && _product!.workerCostsPerProduct.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Column(children: [
                SwitchListTile(
                  value: _overrideWorkers,
                  onChanged: (v) => setState(() => _overrideWorkers = v),
                  title: const Text('Override Worker Assignment',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: const Text('Assign this sale to different workers',
                      style: TextStyle(fontSize: 11)),
                  activeColor: const Color(0xFF1F4E79),
                ),
                
                if (_overrideWorkers && _product != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: _product!.workerCostsPerProduct.entries.map((entry) {
                        final originalRole = entry.key;
                        final cost = entry.value;
                        final ratePerKg = _product!.workerRatesPerKg[originalRole] ?? 0;
                        final currentOverride = _workerOverrides[originalRole];
                        final qty = double.tryParse(_qty.text) ?? 0;
                        final earnings = ratePerKg * qty;
                        
                        // Get available workers
                        final availableWorkers = [
                          {'role': originalRole, 'name': 'Original: $originalRole'},
                          ..._workers.where((w) => w.role != originalRole).map((w) => 
                            {'role': w.role, 'name': '${w.name} (${w.role})'}
                          ),
                        ];
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1F4E79),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(originalRole,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const Spacer(),
                                Text('₹${fmt.format(cost)} per piece',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.arrow_forward, size: 14, color: Color(0xFF888888)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: currentOverride ?? originalRole,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide.none,
                                      ),
                                      filled: true,
                                      fillColor: const Color(0xFFF5F6FA),
                                    ),
                                    items: availableWorkers.map((w) {
                                      return DropdownMenuItem(
                                        value: w['role'],
                                        child: Row(children: [
                                          if (w['role'] == originalRole)
                                            const Icon(Icons.refresh, size: 14, color: Color(0xFF1F4E79)),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(w['name']!,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ]),
                                      );
                                    }).toList(),
                                    onChanged: (newRole) {
                                      setState(() {
                                        if (newRole != null) {
                                          if (newRole == originalRole) {
                                            _workerOverrides.remove(originalRole);
                                          } else {
                                            _workerOverrides[originalRole] = newRole;
                                          }
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ]),
                              if (ratePerKg > 0 && qty > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    'Earns: ₹${fmt.format(ratePerKg)}/kg × $qty kg = ₹${fmt.format(earnings)}',
                                    style: TextStyle(fontSize: 10, 
                                        color: earnings > 0 ? const Color(0xFF1A6B2A) : const Color(0xFF888888),
                                        fontWeight: earnings > 0 ? FontWeight.w500 : FontWeight.normal),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ]),
            ),

          // Price override section
          if (_product != null)
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Change sale price?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text('Default: Rs ${_product!.sellPricePerKg.toStringAsFixed(0)}/kg',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ])),
              Switch(value: _customPrice,
                  onChanged: (v) { setState(() => _customPrice = v); _recalc(); },
                  activeColor: const Color(0xFF1F4E79)),
            ]),

          if (_customPrice && _product != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Sale price per kg (Rs)',
                  prefixText: 'Rs ', suffixText: '/kg',
                  filled: true, fillColor: const Color(0xFFFFF8E1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                ),
                onChanged: (_) => _recalc(),
              ),
            ),

          TextField(
            controller: _qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity (${_product?.unit ?? 'kg / pcs'})',
              suffixText: _product?.unit,
              filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (_) => _recalc(),
          ),
          const SizedBox(height: 14),

          if (_profit != 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _profit >= 0 ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Text('Profit: Rs ${fmt.format(_profit)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                        color: _profit >= 0 ? const Color(0xFF1A6B2A) : Colors.red),
                    textAlign: TextAlign.center),
                if (_customPrice)
                  Text('(Custom price: Rs ${fmt.format(_effectivePrice)}/kg)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
              ]),
            ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: (_product == null || _qty.text.isEmpty || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Sale',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Reusable dropdown ─────────────────────────────────────────────────────────
class _DropField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) caption;
  final ValueChanged<T?> onChanged;

  const _DropField({required this.value, required this.hint, required this.items,
      required this.label, required this.caption, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonFormField<T>(
      value: value,
      hint: Text(hint),
      isExpanded: true,
      decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none),
      items: items.map((item) => DropdownMenuItem<T>(
        value: item,
        child: Row(children: [
          Expanded(child: Text(label(item),
              style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          if (caption(item).isNotEmpty)
            Text(caption(item),
                style: const TextStyle(fontSize: 11, color: Color(0xFF1A6B2A))),
        ]),
      )).toList(),
      onChanged: onChanged,
    ),
  );
}