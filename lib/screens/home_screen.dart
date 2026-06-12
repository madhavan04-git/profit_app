// lib/screens/home_screen.dart - Modern UI with Custom Bottom Bar & Side Drawer
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
import 'investment_tracker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _svc = FirebaseService.instance;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  DateTime _date = DateTime.now();
  List<Sale> _sales = [];
  List<Product> _products = [];
  List<Buyer> _buyers = [];
  List<Worker> _workers = [];
  double _dayProfit = 0;
  double _monthProfit = 0;
  bool _loading = true;
  int _navIndex = 2; // 0=Monthly, 1=Investment, 2=Home, 3=BuyerTx, 4=WorkerTx

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

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
      _products = results[0] as List<Product>;
      _buyers = results[1] as List<Buyer>;
      _workers = results[2] as List<Worker>;
      _sales = sales;
      _dayProfit = sales.fold(0, (s, x) => s + x.profit);
      _monthProfit = results[4] as double;
      _loading = false;
    });
  }

  Future<void> _reloadSales() async {
    final results = await Future.wait([
      _svc.salesForDate(_date),
      _svc.monthlyTotalProfit(_date.year, _date.month),
    ]);
    final sales = results[0] as List<Sale>;
    setState(() {
      _sales = sales;
      _dayProfit = sales.fold(0, (s, x) => s + x.profit);
      _monthProfit = results[1] as double;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date,
        firstDate: DateTime(2024),
        lastDate: DateTime.now());
    if (d != null) {
      setState(() => _date = d);
      _reloadSales();
    }
  }

  void _addSale() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSaleSheet(
        date: _date,
        products: _products,
        buyers: _buyers,
        onSaved: _reloadSales,
      ),
    );
  }

  Future<void> _deleteSale(Sale sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text(
            'Delete ${sale.productName} — Rs ${sale.profit.toStringAsFixed(2)} profit?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteSale(sale.id!);
      _reloadSales();
    }
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Logout?'),
              content: const Text(
                  'Are you sure you want to logout from My Pattarii?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
      body: _buildCurrentBody(),
      floatingActionButton: _navIndex == 2
          ? FloatingActionButton.extended(
              onPressed: _addSale,
              icon: const Icon(Icons.add),
              label: const Text('Add Sale',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white)
          : null,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildCurrentBody() {
    switch (_navIndex) {
      case 0:
        return const MonthlyScreen();
      case 1:
        return const InvestmentTrackerScreen();
      case 2:
        return _buildHome();
      case 3:
        return const BuyerTransactionsScreen();
      case 4:
        return const WorkerTransactionsScreen();
      default:
        return _buildHome();
    }
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
        },
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFF1F4E79).withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Monthly',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes),
            label: 'Investment',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Buyer Tx',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Worker Tx',
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // SIDEBAR DRAWER – Home, Buyers, Workers, Expenses, Products, Logout
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/icon/logo4.png',
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.store,
                              color: Colors.white, size: 30),
                        )),
              ),
              const SizedBox(height: 12),
              Text('My Pattarii',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(user?.displayName ?? user?.email ?? '',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.75), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 8),

          // ── Navigation items ──────────────────────────────────────
          _sideItem(Icons.home, 'Home', () {
            Navigator.pop(context);
            setState(() => _navIndex = 2);
          }, selected: _navIndex == 2),

          _sideItem(Icons.people, 'Buyers', () {
            Navigator.pop(context);
            Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BuyersScreen()))
                .then((_) => _loadAll());
          }),

          _sideItem(Icons.engineering, 'Workers', () {
            Navigator.pop(context);
            Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const WorkersScreen()))
                .then((_) => _loadAll());
          }),

          _sideItem(Icons.receipt_long, 'Expenses', () {
            Navigator.pop(context);
            Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ExpensesScreen()));
          }),

          _sideItem(Icons.inventory_2_outlined, 'Products', () {
            Navigator.pop(context);
            Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProductsScreen()))
                .then((_) => _loadAll());
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
    final c =
        color ?? (selected ? const Color(0xFF1F4E79) : const Color(0xFF444444));
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
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: c)),
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
    final top = MediaQuery.of(context).padding.top;

    return Column(children: [
      Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, top + 10, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            // ★ Logo — tap to open sidebar ★
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/icon/logo4.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1F4E79),
                            child: const Icon(Icons.store,
                                color: Colors.white, size: 24),
                          )),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.displayName?.split(' ').first ?? 'there'}!',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              Text(
                  DateUtils.isSameDay(_date, DateTime.now())
                      ? 'Today — ${DateFormat('dd MMM yyyy').format(_date)}'
                      : DateFormat('EEEE, dd MMM yyyy').format(_date),
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ]),
            const Spacer(),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _miniCard('Today', 'Rs ${fmt.format(_dayProfit)}',
                    const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
            const SizedBox(width: 10),
            Expanded(
                child: _miniCard('This Month', 'Rs ${fmt.format(_monthProfit)}',
                    const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(10)),
                child: const Column(children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: Color(0xFF1F4E79)),
                  SizedBox(height: 3),
                  Text('Date',
                      style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                ]),
              ),
            ),
          ]),
        ]),
      ),
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
                      ..._sales.map((s) =>
                          _SaleCard(sale: s, onDelete: () => _deleteSale(s))),
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
        Text(title,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        const Spacer(),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey)),
            Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
      );

  Widget _miniCard(String label, String value, Color textColor, Color bg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
              overflow: TextOverflow.ellipsis),
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: s.productCategory == 'SS'
                ? const Color(0xFFE6F1FB)
                : const Color(0xFFFAEEDA),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
              child: Text(s.productCategory,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: s.productCategory == 'SS'
                          ? const Color(0xFF1F4E79)
                          : const Color(0xFF7B4F06)))),
        ),
        title: Text(s.productName,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${s.qty % 1 == 0 ? s.qty.toInt() : s.qty.toStringAsFixed(1)} ${s.displayUnit}'
            '${s.buyerName != null ? '  •  ${s.buyerName}' : ''}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('Rs ${fmt.format(s.profit)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A6B2A))),
          const SizedBox(width: 4),
          IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFFCC4444)),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD SALE SHEET - WITH PIECE PRODUCT SUPPORT & WORKER OVERRIDE
// MODIFIED: For piece products, raw material stock (global & buyer) is NOT deducted.
// ══════════════════════════════════════════════════════════════════════════════
class AddSaleSheet extends StatefulWidget {
  final DateTime date;
  final List<Product> products;
  final List<Buyer> buyers;
  final VoidCallback onSaved;
  const AddSaleSheet(
      {super.key,
      required this.date,
      required this.products,
      required this.buyers,
      required this.onSaved});
  @override
  State<AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<AddSaleSheet> {
  Product? _product;
  Buyer? _buyer;
  final _qty = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _customPrice = false;
  double _profit = 0, _effectivePrice = 0;
  bool _saving = false;

  bool _overrideWorkers = false;
  Map<String, String> _workerOverrides = {};
  List<Worker> _workers = [];

  String _buyerStockText = '';
  RawMaterialType? _buyerMaterialType;

  // Global stock info
  String _globalStockText = '';
  double _globalStockKg = 0;
  RawMaterialType? _globalMaterialType;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    _workers = await FirebaseService.instance.getWorkers();
    setState(() {});
  }

  // Map product category to raw material type (for consumption)
  RawMaterialType? _getMaterialTypeFromProduct(Product? p) {
    if (p == null) return null;
    final cat = p.category.toLowerCase();
    if (cat.contains('ss')) return RawMaterialType.ssSheet;
    if (cat.contains('brass')) return RawMaterialType.brassSheet;
    if (cat.contains('copper')) return RawMaterialType.copperSheet;
    return null;
  }

  // Convert sale quantity (pieces or kg) to kg for raw material deduction
  double _getKgConsumed(Product p, double qty) {
    if (p.soldByPiece) {
      // qty is in pieces, each piece weighs p.productWeightG grams
      return qty * (p.productWeightG / 1000.0);
    } else {
      // qty is already in kg
      return qty;
    }
  }

  Future<void> _fetchGlobalStock(RawMaterialType? material) async {
    if (material == null) {
      setState(() {
        _globalStockText = '';
        _globalStockKg = 0;
        _globalMaterialType = null;
      });
      return;
    }
    final kg = await FirebaseService.instance.getCurrentStockForMaterial(material);
    setState(() {
      _globalStockKg = kg;
      _globalMaterialType = material;
      _globalStockText = 'Global ${material.displayName}: ${kg.toStringAsFixed(2)} kg';
    });
  }

  Future<void> _fetchBuyerStock(Buyer? b) async {
    if (b == null || b.id == null) {
      setState(() {
        _buyerStockText = '';
        _buyerMaterialType = null;
      });
      return;
    }
    final stock = await FirebaseService.instance.getPartyStock(b.id!);
    if (stock != null && stock.stock.isNotEmpty) {
      final productMaterial = _getMaterialTypeFromProduct(_product);
      if (productMaterial != null && stock.stock.containsKey(productMaterial)) {
        final kg = stock.stock[productMaterial]!;
        setState(() {
          _buyerMaterialType = productMaterial;
          _buyerStockText = 'Remaining ${productMaterial.displayName}: ${kg.toStringAsFixed(2)} kg';
        });
      } else {
        final first = stock.stock.entries.first;
        setState(() {
          _buyerMaterialType = first.key;
          _buyerStockText = 'Remaining ${first.key.displayName}: ${first.value.toStringAsFixed(2)} kg';
        });
      }
    } else {
      setState(() {
        _buyerStockText = 'No raw material stock for this buyer.';
        _buyerMaterialType = null;
      });
    }
  }

  void _selectProduct(Product? p) {
    final material = _getMaterialTypeFromProduct(p);
    setState(() {
      _product = p;
      if (p != null) {
        if (p.soldByPiece) {
          final defaultPiecePrice = p.sellPricePerKg * (p.productWeightG / 1000.0);
          _effectivePrice = defaultPiecePrice;
          _priceCtrl.text = defaultPiecePrice.toStringAsFixed(2);
        } else {
          _effectivePrice = p.sellPricePerKg;
          _priceCtrl.text = _effectivePrice.toStringAsFixed(0);
        }
      } else {
        _effectivePrice = 0;
        _priceCtrl.text = '';
      }
      _workerOverrides.clear();
      _overrideWorkers = false;
    });
    _recalc();
    if (_buyer != null) _fetchBuyerStock(_buyer);
    _fetchGlobalStock(material);
  }

  void _onBuyerChanged(Buyer? b) {
    setState(() => _buyer = b);
    _fetchBuyerStock(b);
    _recalc();
  }

  void _recalc() {
    if (_product == null) {
      setState(() => _profit = 0);
      return;
    }
    final qty = double.tryParse(_qty.text) ?? 0;
    final p = _product!;
    double profit;
    if (_customPrice) {
      double customPrice = double.tryParse(_priceCtrl.text) ?? 0;
      _effectivePrice = customPrice;
      if (p.soldByPiece) {
        final costPerPiece = p.costPerKg * (p.productWeightG / 1000.0);
        final profitPerPiece = customPrice - costPerPiece;
        profit = qty * profitPerPiece;
      } else {
        final profitPerKg = customPrice - p.costPerKg;
        profit = qty * profitPerKg;
      }
    } else {
      if (p.soldByPiece) {
        final defaultPiecePrice = p.sellPricePerKg * (p.productWeightG / 1000.0);
        _effectivePrice = defaultPiecePrice;
        final costPerPiece = p.costPerKg * (p.productWeightG / 1000.0);
        profit = qty * (defaultPiecePrice - costPerPiece);
      } else {
        _effectivePrice = p.sellPricePerKg;
        profit = p.profitForQty(qty);
      }
    }
    setState(() => _profit = profit);
  }

  // Get final worker rates with overrides (in kg or piece basis)
  Map<String, double> _getFinalWorkerRates() {
    if (_product == null) return {};
    final baseRates = Map<String, double>.from(_product!.workerRatesPerKg);
    if (!_overrideWorkers || _workerOverrides.isEmpty) return baseRates;
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
    final qty = double.tryParse(_qty.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid quantity')));
      return;
    }

    // For piece products: DO NOT check or deduct raw material stock (global or buyer)
    // Only kg-based products affect inventory.
    final isPieceProduct = _product!.soldByPiece;

    if (!isPieceProduct) {
      // kg product – check and deduct stock
      final kgConsumed = _getKgConsumed(_product!, qty);

      // Check buyer stock (if buyer has stock for this material)
      if (_buyer != null &&
          _buyerMaterialType != null &&
          _buyerStockText.isNotEmpty &&
          !_buyerStockText.contains('No raw material')) {
        final stock = await FirebaseService.instance.getPartyStock(_buyer!.id!);
        final available = stock?.stock[_buyerMaterialType!] ?? 0;
        if (available < kgConsumed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Insufficient buyer raw material! Only ${available.toStringAsFixed(2)} kg available.'),
              backgroundColor: Colors.red));
          return;
        }
      }

      // Check global stock
      final globalMaterial = _getMaterialTypeFromProduct(_product);
      if (globalMaterial != null) {
        final globalStock = await FirebaseService.instance.getCurrentStockForMaterial(globalMaterial);
        if (globalStock < kgConsumed) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Insufficient global stock! Only ${globalStock.toStringAsFixed(2)} kg available.'),
              backgroundColor: Colors.red));
          return;
        }
      }

      // Deduct from buyer's raw material stock (if any)
      if (_buyer != null && _buyer!.id != null && _buyerMaterialType != null) {
        await FirebaseService.instance.updatePartyStock(
          _buyer!.id!,
          _buyer!.name,
          'buyer',
          _buyerMaterialType!,
          -kgConsumed,
        );
      }

      // Deduct from global stock by adding a consumption transaction
      if (globalMaterial != null) {
        final consumptionTx = RawMaterialTransaction(
          materialType: globalMaterial,
          date: widget.date,
          quantityKg: -kgConsumed,
          ratePerKg: 0,
          transactionType: 'consumption',
          supplierId: _buyer?.id,
          supplierName: _buyer?.name,
          note: 'Consumed for sale: ${_product!.name} (${qty} kg)',
        );
        await FirebaseService.instance.addRawMaterialTransaction(consumptionTx);
      }
    }

    setState(() => _saving = true);
    final saleAmount = _product!.soldByPiece ? qty * _effectivePrice : qty * _effectivePrice;
    final finalWorkerRates = _getFinalWorkerRates();

    final sale = Sale(
      productId: _product!.id!,
      productName: _product!.name,
      productCategory: _product!.category,
      buyerId: _buyer?.id,
      buyerName: _buyer?.name,
      qty: qty,
      salePrice: _effectivePrice,
      profit: _profit,
      date: widget.date,
      workerRatesPerKg: finalWorkerRates,
      soldByPiece: _product!.soldByPiece,
      unit: _product!.soldByPiece ? 'pcs' : 'kg',
    );
    await FirebaseService.instance.addSale(sale);

    // No auto-credit transaction – payments are manual only
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 6, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Row(children: [
            const Text('Add Sale',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(DateFormat('dd MMM yyyy').format(widget.date),
                style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
          ]),
          const SizedBox(height: 16),

          _DropField<Product>(
            value: _product,
            hint: 'Select product *',
            items: widget.products,
            label: (p) => '${p.category} — ${p.name} (${p.soldByPiece ? 'per piece' : 'per kg'})',
            caption: (p) => p.soldByPiece
                ? 'Rs ${fmt.format(p.sellPricePerKg * (p.productWeightG / 1000.0))}/pc'
                : 'Rs ${fmt.format(p.sellPricePerKg)}/kg',
            onChanged: _selectProduct,
          ),
          const SizedBox(height: 10),

          if (_product != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline,
                    size: 14, color: Color(0xFF1F4E79)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                      _product!.soldByPiece
                          ? 'Weight per piece: ${_product!.productWeightG}g  •  '
                              'Cost per piece: Rs ${fmt.format(_product!.costPerKg * (_product!.productWeightG / 1000.0))}  •  '
                              'Profit per piece: Rs ${fmt.format(_product!.profitPerPiece)}'
                          : 'Sell: Rs ${_product!.sellPricePerKg.toStringAsFixed(0)}/kg  •  '
                              'Cost: Rs ${fmt.format(_product!.costPerKg)}/kg  •  '
                              'Profit: Rs ${fmt.format(_product!.profitPerUnit)}/${_product!.unit}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF1F4E79)))),
              ]),
            ),

          _DropField<Buyer?>(
            value: _buyer,
            hint: 'Select buyer (optional)',
            items: [null, ...widget.buyers],
            label: (b) => b == null ? 'No buyer' : b.name,
            caption: (b) => b == null ? '' : b.phone,
            onChanged: _onBuyerChanged,
          ),

          // Display global stock (only for kg products)
          if (_globalStockText.isNotEmpty && _product != null && !_product!.soldByPiece)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _globalStockText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1F4E79),
                  ),
                ),
              ),
            ),

          // Display buyer stock (only for kg products)
          if (_buyerStockText.isNotEmpty && _product != null && !_product!.soldByPiece)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _buyerStockText.contains('No')
                      ? Colors.grey.shade100
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _buyerStockText,
                  style: TextStyle(
                    fontSize: 12,
                    color: _buyerStockText.contains('No')
                        ? Colors.grey.shade700
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 10),

          // Worker Override Section (always works for any product type)
          if (_product != null &&
              _workers.isNotEmpty &&
              _product!.workerCostsPerProduct.isNotEmpty)
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
                        final rateDisplay = _product!.soldByPiece
                            ? '₹${fmt.format(cost)}/piece'
                            : '₹${fmt.format(_product!.workerRatesPerKg[originalRole] ?? 0)}/kg';
                        final currentOverride = _workerOverrides[originalRole];
                        final qty = double.tryParse(_qty.text) ?? 0;
                        double earnings = 0;
                        if (_product!.soldByPiece) {
                          earnings = cost * qty;
                        } else {
                          final ratePerKg = _product!.workerRatesPerKg[originalRole] ?? 0;
                          earnings = ratePerKg * qty;
                        }

                        final availableWorkers = [
                          {'role': originalRole, 'name': 'Original: $originalRole'},
                          ..._workers.where((w) => w.role != originalRole).map((w) =>
                              {'role': w.role, 'name': '${w.name} (${w.role})'}),
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
                                Container(width: 8, height: 8,
                                    decoration: BoxDecoration(color: const Color(0xFF1F4E79), shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Text(originalRole, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const Spacer(),
                                Text(rateDisplay, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
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
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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
                                          Expanded(child: Text(w['name']!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
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
                              if (qty > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('Earns: ₹${fmt.format(earnings)}',
                                      style: TextStyle(fontSize: 10,
                                          color: earnings > 0 ? const Color(0xFF1A6B2A) : const Color(0xFF888888),
                                          fontWeight: earnings > 0 ? FontWeight.w500 : FontWeight.normal)),
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
                const Text('Change sale price?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Text(_product!.soldByPiece
                    ? 'Default: Rs ${(_product!.sellPricePerKg * (_product!.productWeightG / 1000.0)).toStringAsFixed(2)}/piece'
                    : 'Default: Rs ${_product!.sellPricePerKg.toStringAsFixed(0)}/kg',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
              ])),
              Switch(value: _customPrice, onChanged: (v) { setState(() => _customPrice = v); _recalc(); }, activeColor: const Color(0xFF1F4E79)),
            ]),

          if (_customPrice && _product != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 4),
              child: TextField(
                controller: _priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _product!.soldByPiece ? 'Sale price per piece (Rs)' : 'Sale price per kg (Rs)',
                  prefixText: 'Rs ',
                  suffixText: _product!.soldByPiece ? '/pc' : '/kg',
                  filled: true,
                  fillColor: const Color(0xFFFFF8E1),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                  Text(_product!.soldByPiece
                      ? '(Custom price: Rs ${fmt.format(_effectivePrice)}/piece)'
                      : '(Custom price: Rs ${fmt.format(_effectivePrice)}/kg)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF555555))),
              ]),
            ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_product == null || _qty.text.isEmpty || _saving) ? null : _save,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DropField<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) label;
  final String Function(T) caption;
  final ValueChanged<T?> onChanged;

  const _DropField(
      {required this.value,
      required this.hint,
      required this.items,
      required this.label,
      required this.caption,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: const Color(0xFFF5F6FA),
            borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonFormField<T>(
          value: value,
          hint: Text(hint),
          isExpanded: true,
          decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Row(children: [
                      Expanded(
                          child: Text(label(item),
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis)),
                      if (caption(item).isNotEmpty)
                        Text(caption(item),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF1A6B2A))),
                    ]),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      );
}