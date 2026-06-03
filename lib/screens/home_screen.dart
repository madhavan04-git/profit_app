// lib/screens/home_screen.dart
// FIXES:
// 1. Products and buyers loaded once on init — not on every "Add Sale" tap
// 2. Add Sale sheet opens instantly from cache
// 3. Sales list uses local state — no stream rebuild lag
// 4. Buyer total price editable per sale

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'monthly_screen.dart';
import 'buyers_screen.dart';
import 'workers_screen.dart';
import 'expenses_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _svc = FirebaseService.instance;
  DateTime _date = DateTime.now();
  List<Sale> _sales = [];
  List<Product> _products = []; // cached — loaded once
  List<Buyer> _buyers = [];     // cached — loaded once
  double _dayProfit = 0, _monthProfit = 0;
  bool _loading = true;
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // Load products + buyers once, sales for today — all in parallel
  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _svc.getProducts(),
      _svc.getBuyers(),
      _svc.salesForDate(_date),
      _svc.monthlyTotalProfit(_date.year, _date.month),
    ]);
    final sales = results[2] as List<Sale>;
    setState(() {
      _products    = results[0] as List<Product>;
      _buyers      = results[1] as List<Buyer>;
      _sales       = sales;
      _dayProfit   = sales.fold(0, (s, x) => s + x.profit);
      _monthProfit = results[3] as double;
      _loading     = false;
    });
  }

  // Only reload sales — products/buyers already cached
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
    if (d != null) {
      setState(() => _date = d);
      _reloadSales();
    }
  }

  // Instant — products already loaded
  void _addSale()async  {
    print("Products loaded: ${_products.length}");
print("Buyers loaded: ${_buyers.length}");
    // if (_products.isEmpty) {
    //   ScaffoldMessenger.of(context).showSnackBar  (
    //       const SnackBar(content: Text('Loading products... please wait')));
    //   return;
    // }
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
        content: Text('Delete ${sale.productName} — Rs ${sale.profit.toStringAsFixed(2)} profit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteSale(sale.id!);
      _reloadSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _navIndex == 0 ? _buildHome()
          : _navIndex == 1 ? const BuyersScreen()
          : _navIndex == 2 ? const WorkersScreen()
          : const ExpensesScreen(),
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _addSale,
              icon: const Icon(Icons.add),
              label: const Text('Add Sale', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white)
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

  Widget _buildHome() {
    final fmt = NumberFormat('#,##0', 'en_IN');
    final user = _svc.currentUser;
    final top  = MediaQuery.of(context).padding.top;

    return Column(children: [
      // ── Header ─────────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, top + 10, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user?.displayName?.split(' ').first ?? 'there'}!',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                      color: Color(0xFF1F4E79))),
              Text(DateUtils.isSameDay(_date, DateTime.now())
                  ? 'Today — ${DateFormat('dd MMM yyyy').format(_date)}'
                  : DateFormat('EEEE, dd MMM yyyy').format(_date),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ]),
            const Spacer(),
            _topBtn(Icons.inventory_2_outlined, 'Products', () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProductsScreen()))
                .then((_) => _loadAll())),
            _topBtn(Icons.bar_chart_rounded, 'Monthly', () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const MonthlyScreen()))
                .then((_) => _reloadSales())),
            _topBtn(Icons.settings_outlined, 'Settings', () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _miniCard('Today',
                'Rs ${fmt.format(_dayProfit)}',
                const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
            const SizedBox(width: 10),
            Expanded(child: _miniCard('This month',
                'Rs ${fmt.format(_monthProfit)}',
                _monthProfit >= 30000 ? const Color(0xFF1A6B2A) : const Color(0xFF7B4F06),
                _monthProfit >= 30000 ? const Color(0xFFC6EFCE) : const Color(0xFFFFF3CD))),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1F4E79)),
                  const SizedBox(height: 2),
                  Text(DateFormat('dd MMM').format(_date),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: Color(0xFF1F4E79))),
                ]),
              ),
            ),
          ]),
        ]),
      ),

      // ── Month progress ──────────────────────────────────────────────────
      _MonthBar(monthProfit: _monthProfit, date: _date),

      // ── Sales list ──────────────────────────────────────────────────────
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (_sales.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No sales yet', style: TextStyle(fontSize: 18,
              color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Tap + Add Sale below', style: TextStyle(
              fontSize: 13, color: Colors.grey.shade400)),
        ])))
      else
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _sales.length,
            itemBuilder: (_, i) {
              final s = _sales[i];
              return _SaleTile(sale: s, onDelete: () => _deleteSale(s));
            },
          ),
        ),
    ]);
  }

  Widget _topBtn(IconData icon, String label, VoidCallback onTap) =>
      InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Column(children: [
            Icon(icon, size: 22, color: const Color(0xFF1F4E79)),
            Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
          ])));

  Widget _miniCard(String label, String value, Color color, Color bg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ]),
      );
}

// ── Month bar — takes pre-loaded value, no extra fetch ────────────────────────
class _MonthBar extends StatelessWidget {
  final double monthProfit;
  final DateTime date;
  const _MonthBar({required this.monthProfit, required this.date});

  @override
  Widget build(BuildContext context) {
    const target = 30000.0;
    final pct = (monthProfit / target).clamp(0.0, 1.0);
    final fmt = NumberFormat('#,##0', 'en_IN');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(children: [
          Text(DateFormat('MMM yyyy').format(date),
              style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
          const Spacer(),
          Text('Rs ${fmt.format(monthProfit)} / 30,000',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Color(0xFF1F4E79))),
        ]),
        const SizedBox(height: 5),
        ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct, minHeight: 6,
              backgroundColor: const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation(
                  pct >= 1.0 ? const Color(0xFF639922)
                      : pct >= 0.7 ? const Color(0xFFEF9F27)
                      : const Color(0xFF378ADD)),
            )),
        const SizedBox(height: 4),
        Text(
          pct >= 1.0
              ? '✓ Target reached! +Rs ${fmt.format(monthProfit - target)} extra'
              : 'Rs ${fmt.format(target - monthProfit)} more needed',
          style: TextStyle(fontSize: 10,
              color: pct >= 1.0 ? const Color(0xFF1A6B2A) : const Color(0xFF888888)),
        ),
      ]),
    );
  }
}

// ── Sale tile ─────────────────────────────────────────────────────────────────
class _SaleTile extends StatelessWidget {
  final Sale sale;
  final VoidCallback onDelete;
  const _SaleTile({required this.sale, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isSS  = sale.productCategory == 'SS';
    final color = isSS ? const Color(0xFF1F4E79) : const Color(0xFF7B4F06);
    final bg    = isSS ? const Color(0xFFE6F1FB) : const Color(0xFFFAEEDA);
    final fmt   = NumberFormat('#,##0.00', 'en_IN');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 4, offset: const Offset(0, 2))]),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(width: 42, height: 42,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(child: Text(
                sale.productCategory.length >= 2
                    ? sale.productCategory.substring(0, 2)
                    : sale.productCategory,
                style: TextStyle(color: color,
                    fontWeight: FontWeight.bold, fontSize: 12)))),
        title: Text(sale.productName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${sale.qty % 1 == 0 ? sale.qty.toInt() : sale.qty.toStringAsFixed(1)}'
            ' ${sale.qty == 1 ? "unit" : "units"}  •  '
            'Rs ${fmt.format(sale.salePrice)}/kg',
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          if (sale.buyerName != null && sale.buyerName!.isNotEmpty)
            Text('Buyer: ${sale.buyerName}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1F4E79))),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Rs ${fmt.format(sale.profit)}',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    color: Color(0xFF1A6B2A), fontSize: 15)),
            const Text('profit', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
          ]),
          const SizedBox(width: 6),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFCC4444)),
              onPressed: onDelete, padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ADD SALE SHEET — instant open (products pre-cached), custom price per buyer
// ══════════════════════════════════════════════════════════════════════════════
class AddSaleSheet extends StatefulWidget {
  final DateTime date;
  final List<Product> products;
  final List<Buyer> buyers;
  final VoidCallback onSaved;
  const AddSaleSheet({super.key, required this.date,
      required this.products, required this.buyers, required this.onSaved});
  @override
  State<AddSaleSheet> createState() => _AddSaleSheetState();
}

class _AddSaleSheetState extends State<AddSaleSheet> {
  Product? _product;
  Buyer?   _buyer;
  final _qty       = TextEditingController();
  final _priceCtrl = TextEditingController();
  bool _customPrice = false;
  double _profit = 0;
  double _effectivePrice = 0;
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _selectProduct(Product? p) {
    setState(() {
      _product = p;
      if (p != null) {
        _effectivePrice = p.sellPricePerKg;
        _priceCtrl.text = p.sellPricePerKg.toStringAsFixed(0);
      }
    });
    _recalc();
  }

  void _recalc() {
    final qty = double.tryParse(_qty.text) ?? 0;
    if (_product == null || qty == 0) { setState(() => _profit = 0); return; }

    final price = _customPrice
        ? (double.tryParse(_priceCtrl.text) ?? _product!.sellPricePerKg)
        : _product!.sellPricePerKg;

    final profitPerKg  = price - _product!.costPerKg;
    final profitPerUnit = _product!.soldByPiece
        ? profitPerKg * (_product!.productWeightG / 1000)
        : profitPerKg;

    setState(() {
      _effectivePrice = price;
      _profit = qty * profitPerUnit;
    });
  }

  Future<void> _save() async {
    if (_product == null || _saving) return;
    final qty = double.tryParse(_qty.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter quantity')));
      return;
    }
    setState(() => _saving = true);
    await FirebaseService.instance.addSale(Sale(
      productId:       _product!.id!,
      productName:     _product!.name,
      productCategory: _product!.category,
      buyerId:         _buyer?.id,
      buyerName:       _buyer?.name,
      qty:             qty,
      salePrice:       _effectivePrice,
      profit:          _profit,
      date:            widget.date,
    ));
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
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),

        Row(children: [
          const Text('Add Sale',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(DateFormat('dd MMM yyyy').format(widget.date),
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
        ]),
        const SizedBox(height: 16),

        // ── Product ──────────────────────────────────────────────────────
        _DropField<Product>(
          value: _product,
          hint: 'Select product *',
          items: widget.products,
          label:   (p) => '${p.category} — ${p.name}',
          caption: (p) => 'Profit Rs ${fmt.format(p.profitPerUnit)}/${p.unit}',
          onChanged: _selectProduct,
        ),
        const SizedBox(height: 10),

        // Info bar
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

        // ── Buyer (optional) ─────────────────────────────────────────────
        _DropField<Buyer?>(
          value: _buyer,
          hint: 'Select buyer (optional)',
          items: [null, ...widget.buyers],
          label:   (b) => b == null ? 'No buyer' : b.name,
          caption: (b) => b == null ? '' : b.phone,
          onChanged: (b) => setState(() => _buyer = b),
        ),
        const SizedBox(height: 10),

        // ── Change price for this buyer? ──────────────────────────────────
        if (_product != null)
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Change sale price?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('Default: Rs ${_product!.sellPricePerKg.toStringAsFixed(0)}/kg',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ])),
            Switch(
              value: _customPrice,
              onChanged: (v) { setState(() => _customPrice = v); _recalc(); },
              activeColor: const Color(0xFF1F4E79),
            ),
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
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFEF9F27))),
              ),
              onChanged: (_) => _recalc(),
            ),
          ),

        // ── Quantity ──────────────────────────────────────────────────────
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

        // ── Profit preview ────────────────────────────────────────────────
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

        // ── Save ──────────────────────────────────────────────────────────
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
      ])),
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