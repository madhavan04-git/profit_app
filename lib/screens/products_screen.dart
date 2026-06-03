// lib/screens/products_screen.dart
// FIX: Was using DatabaseHelper (SQLite). Now uses FirebaseService (Firestore).
// This is why products were not showing in Firebase dashboard.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _svc = FirebaseService.instance; // ← FIXED: was DatabaseHelper
  List<Product> _products = [];
  bool _showInactive = false;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = _showInactive
        ? await _svc.getAllProducts()
        : await _svc.getProducts();
    setState(() { _products = list; _loading = false; });
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
    _load();
  }

  Future<void> _confirmDeactivate(Product p) async {
    final ok = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disable product?'),
        content: Text('"${p.name}" will be hidden from sales.\nPast sales data is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );
    if (ok == true) { await _svc.deactivateProduct(p.id!); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');

    // Group by category
    final Map<String, List<Product>> groups = {};
    for (final p in _products) {
      groups.putIfAbsent(p.category, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          Row(children: [
            const Text('Show disabled', style: TextStyle(fontSize: 12)),
            Switch(
              value: _showInactive,
              onChanged: (v) { setState(() => _showInactive = v); _load(); },
              activeColor: const Color(0xFF1F4E79),
            ),
          ]),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('No products yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Product'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white),
                  ),
                ]))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...groups.entries.map((entry) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: entry.key == 'SS'
                                    ? const Color(0xFF1F4E79)
                                    : entry.key == 'Brass'
                                        ? const Color(0xFF7B4F06)
                                        : const Color(0xFF555555),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(entry.key,
                                  style: const TextStyle(color: Colors.white,
                                      fontSize: 13, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text('${entry.value.length} products',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                          ]),
                        ),
                        ...entry.value.map((p) => _ProductCard(
                          product: p, fmt: fmt,
                          onEdit: () => _openForm(product: p),
                          onDisable: () => _confirmDeactivate(p),
                        )),
                        const SizedBox(height: 8),
                      ],
                    )),
                    const SizedBox(height: 80),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Product'),
        backgroundColor: const Color(0xFF1F4E79),
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final NumberFormat fmt;
  final VoidCallback onEdit, onDisable;
  const _ProductCard({required this.product, required this.fmt,
      required this.onEdit, required this.onDisable});

  @override
  Widget build(BuildContext context) {
    final isSS    = product.category == 'SS';
    final color   = isSS ? const Color(0xFF1F4E79) : const Color(0xFF7B4F06);
    final bg      = isSS ? const Color(0xFFE6F1FB) : const Color(0xFFFAEEDA);
    final isActive = product.isActive;

    return Opacity(
      opacity: isActive ? 1.0 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE))),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(child: Text(product.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              if (!isActive)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('DISABLED',
                        style: TextStyle(fontSize: 10, color: Colors.orange,
                            fontWeight: FontWeight.bold))),
              if (isActive) IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: color),
                onPressed: onEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (isActive) IconButton(
                icon: const Icon(Icons.block_outlined, size: 18, color: Colors.orange),
                onPressed: onDisable,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              // Chips
              Wrap(spacing: 6, runSpacing: 4, children: [
                _chip('${product.productWeightG}g/piece'),
                _chip('Sell Rs ${product.sellPricePerKg.toStringAsFixed(0)}/kg'),
                _chip(product.soldByPiece ? 'Sold per piece' : 'Sold per kg'),
                if (product.padii.isNotEmpty) _chip(product.padii),
              ]),
              const SizedBox(height: 10),
              // Costs
              _CostGrid(product: product),
              const SizedBox(height: 8),
              // Profit summary
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFC6EFCE), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text('Cost/kg: Rs ${fmt.format(product.costPerKg)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
                  const Spacer(),
                  Text('Profit: Rs ${fmt.format(product.profitPerUnit)}/${product.unit}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A6B2A))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF555555))));
}

class _CostGrid extends StatelessWidget {
  final Product product;
  const _CostGrid({required this.product});

  @override
  Widget build(BuildContext context) {
    final items = [
      if (product.costMaterial > 0) _CostItem('Material', product.costMaterial),
      if (product.costLabour  > 0) _CostItem('Labour',   product.costLabour),
      if (product.costPlasma  > 0) _CostItem('Plasma',   product.costPlasma),
      if (product.costVettu   > 0) _CostItem('Vettu',    product.costVettu),
      if (product.costWelding > 0) _CostItem('Welding',  product.costWelding),
      if (product.costRunner  > 0) _CostItem('Runner',   product.costRunner),
      if (product.costVarai   > 0) _CostItem('Varai',    product.costVarai),
      if (product.costPolish  > 0) _CostItem('Polish',   product.costPolish),
    ];
    return Wrap(spacing: 8, runSpacing: 4, children: items.map((i) =>
        Text('${i.label}: Rs ${i.val.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF888888)))).toList());
  }
}

class _CostItem { final String label; final double val; const _CostItem(this.label, this.val); }

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT FORM — create & edit, uses FirebaseService
// ══════════════════════════════════════════════════════════════════════════════
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name, _category, _padii,
      _weightG, _sellPrice, _labour, _plasma, _vettu,
      _welding, _runner, _varai, _polish, _material;
  bool _soldByPiece = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name      = TextEditingController(text: p?.name      ?? '');
    _category  = TextEditingController(text: p?.category  ?? '');
    _padii     = TextEditingController(text: p?.padii     ?? '');
    _weightG   = TextEditingController(text: p?.productWeightG.toString() ?? '');
    _sellPrice = TextEditingController(text: p?.sellPricePerKg.toString() ?? '');
    _labour    = TextEditingController(text: (p?.costLabour  ?? 0).toString());
    _plasma    = TextEditingController(text: (p?.costPlasma  ?? 0).toString());
    _vettu     = TextEditingController(text: (p?.costVettu   ?? 0).toString());
    _welding   = TextEditingController(text: (p?.costWelding ?? 0).toString());
    _runner    = TextEditingController(text: (p?.costRunner  ?? 0).toString());
    _varai     = TextEditingController(text: (p?.costVarai   ?? 0).toString());
    _polish    = TextEditingController(text: (p?.costPolish  ?? 0).toString());
    _material  = TextEditingController(text: (p?.costMaterial ?? 0).toString());
    _soldByPiece = p?.soldByPiece ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name,_category,_padii,_weightG,_sellPrice,
      _labour,_plasma,_vettu,_welding,_runner,_varai,_polish,_material]) {
      c.dispose();
    }
    super.dispose();
  }

double _v(TextEditingController c) =>
    double.tryParse(c.text) ?? 0;

  double get _totalCost =>
      (_v(_labour) + _v(_plasma) + _v(_vettu) + _v(_welding) +
       _v(_runner) + _v(_varai) + _v(_polish) + _v(_material));

  // double _v(TextEditingController c) => double.tryParse(c.text) ?? 0;

  double get _profitPreview {
    final wg   = int.tryParse(_weightG.text) ?? 1;
    final sell = double.tryParse(_sellPrice.text) ?? 0;
    final cpk  = _totalCost * (1000 / wg);
    final ppk  = sell - cpk;
    return _soldByPiece ? ppk * (wg / 1000) : ppk;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final product = Product(
      id:              widget.product?.id,
      name:            _name.text.trim(),
      category:        _category.text.trim(),
      padii:           _padii.text.trim(),
      productWeightG:  int.tryParse(_weightG.text) ?? 0,
      sellPricePerKg:  double.tryParse(_sellPrice.text) ?? 0,
      soldByPiece:     _soldByPiece,
      unit:            _soldByPiece ? 'pcs' : 'kg',
      costLabour:      _v(_labour),
      costPlasma:      _v(_plasma),
      costVettu:       _v(_vettu),
      costWelding:     _v(_welding),
      costRunner:      _v(_runner),
      costVarai:       _v(_varai),
      costPolish:      _v(_polish),
      costMaterial:    _v(_material),
    );

    await FirebaseService.instance.saveProduct(product); // ← FIREBASE
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt     = NumberFormat('#,##0.00', 'en_IN');
    final isEdit  = widget.product != null;
    final profitColor = _profitPreview >= 0
        ? const Color(0xFF1A6B2A) : Colors.red;
    final profitBg = _profitPreview >= 0
        ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC);

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Product' : 'New Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('Product Info'),
            _tf(_name,      'Product name *',   required: true),
            _tf(_category,  'Category (SS / Brass / custom) *', required: true),
            _tf(_padii,     'Padii / size label', hint: 'e.g. 1½ padii'),
            _tf(_weightG,   'Weight per piece (grams) *',
                type: TextInputType.number, required: true, suffix: 'g'),
            _tf(_sellPrice, 'Selling price per kg *',
                type: TextInputType.number, required: true, suffix: 'Rs/kg'),

            // Sold by piece toggle
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sold by piece?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(_soldByPiece
                      ? 'Profit calculated per piece (e.g. SS-IV)'
                      : 'Profit calculated per kg (default)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                ])),
                Switch(value: _soldByPiece,
                    onChanged: (v) => setState(() => _soldByPiece = v),
                    activeColor: const Color(0xFF1F4E79)),
              ]),
            ),

            _sectionHeader('Cost Breakdown  (per ${_weightG.text.isEmpty ? "piece" : "${_weightG.text}g"})'),

            Row(children: [
              Expanded(child: _tf(_material, 'Material',  type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_labour,   'Labour',    type: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: _tf(_plasma,   'Plasma',    type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_vettu,    'Vettu',     type: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: _tf(_welding,  'Welding',   type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_runner,   'Runner',    type: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: _tf(_varai,    'Varai',     type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_polish,   'Polish',    type: TextInputType.number)),
            ]),

            // Live profit preview
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: profitBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Row(children: [
                  const Text('Total cost per piece:'),
                  const Spacer(),
                  Text('Rs ${fmt.format(_totalCost)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                if (_weightG.text.isNotEmpty)
                  Row(children: [
                    const Text('Cost per kg:'),
                    const Spacer(),
                    Text('Rs ${fmt.format(_totalCost * (1000 / (int.tryParse(_weightG.text) ?? 1)))}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                const Divider(height: 16),
                Row(children: [
                  Text('Net profit per ${_soldByPiece ? "piece" : "kg"}:',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('Rs ${fmt.format(_profitPreview)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: profitColor)),
                ]),
              ]),
            ),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Save Changes' : 'Create Product',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(text, style: const TextStyle(fontSize: 14,
        fontWeight: FontWeight.bold, color: Color(0xFF1F4E79))));

  Widget _tf(TextEditingController ctrl, String label,
      {bool required = false, String? hint, String? suffix,
       TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label, hintText: hint, suffixText: suffix,
          filled: true, fillColor: const Color(0xFFF5F6FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      ),
    );
  }
}