// lib/screens/products_screen.dart
// My Pattarii — Products screen
// Cost fields: Material, Plasma, Labour 1-4, Vettu 1-2, Welding 1-2,
//              Runner 1-2, Varai, Polish 1-2, Spinner 1-2
// Profit = sellPricePerKg - costPerKg  (all costs deducted including material)
// For piece products: profit = profitPerKg × (weightG/1000)

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
  final _svc = FirebaseService.instance;
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                if (product.padii.isNotEmpty)
                  Text(product.padii,
                      style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
              ])),
              if (!isActive)
                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('DISABLED',
                        style: TextStyle(fontSize: 10, color: Colors.orange,
                            fontWeight: FontWeight.bold))),
              if (isActive) IconButton(
                icon: Icon(Icons.edit_outlined, size: 18, color: color),
                onPressed: onEdit, padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              if (isActive) IconButton(
                icon: const Icon(Icons.block_outlined, size: 18, color: Colors.orange),
                onPressed: onDisable, padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              // Key metrics row
              Row(children: [
                _kv('Weight', '${product.productWeightG}g', color),
                _kv('Sell', 'Rs ${fmt.format(product.sellPricePerKg)}/kg', color),
                _kv('Cost/kg', 'Rs ${fmt.format(product.costPerKg)}', Colors.red.shade700),
                _kv('Profit/${product.unit}',
                    'Rs ${fmt.format(product.profitPerUnit)}',
                    product.profitPerUnit >= 0
                        ? const Color(0xFF1A6B2A) : Colors.red),
              ]),
              const SizedBox(height: 8),
              // Cost breakdown chips
              _CostChips(p: product),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _kv(String label, String value, Color color) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF888888))),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

class _CostChips extends StatelessWidget {
  final Product p;

  const _CostChips({
    super.key,
    required this.p,
  });
  @override
  Widget build(BuildContext context) {
    final costs = p.workerCostsPerProduct;
    if (costs.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat('#,##0.0', 'en_IN');
    return Wrap(spacing: 6, runSpacing: 4, children: [
      if (p.costMaterial > 0) _chip('Material', p.costMaterial, const Color(0xFF7B4F06), fmt),
      ...costs.entries.map((e) => _chip(e.key, e.value, const Color(0xFF1F4E79), fmt)),
    ]);
  }

  Widget _chip(String label, double val, Color color, NumberFormat fmt) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text('$label: Rs ${fmt.format(val)}',
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT FORM
// ══════════════════════════════════════════════════════════════════════════════
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});
  @override State<ProductFormScreen> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _soldByPiece = false;
  bool _saving = false;

  late final TextEditingController _name, _category, _padii, _weightG, _sellPrice;

  // Cost controllers — multi-worker
  late final TextEditingController
      _material, _plasma,
      _labour1, _labour2, _labour3, _labour4,
      _vettu1,  _vettu2,
      _welding1, _welding2,
      _runner1,  _runner2,
      _varai,
      _polish1, _polish2,
      _spinner1, _spinner2;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name     = TextEditingController(text: p?.name     ?? '');
    _category = TextEditingController(text: p?.category ?? '');
    _padii    = TextEditingController(text: p?.padii    ?? '');
    _weightG  = TextEditingController(text: p?.productWeightG.toString() ?? '');
    _sellPrice= TextEditingController(text: p?.sellPricePerKg.toString() ?? '');
    _soldByPiece = p?.soldByPiece ?? false;

    _material = _c(p?.costMaterial);
    _plasma   = _c(p?.costPlasma);
    _labour1  = _c(p?.costLabour1);
    _labour2  = _c(p?.costLabour2);
    _labour3  = _c(p?.costLabour3);
    _labour4  = _c(p?.costLabour4);
    _vettu1   = _c(p?.costVettu1);
    _vettu2   = _c(p?.costVettu2);
    _welding1 = _c(p?.costWelding1);
    _welding2 = _c(p?.costWelding2);
    _runner1  = _c(p?.costRunner1);
    _runner2  = _c(p?.costRunner2);
    _varai    = _c(p?.costVarai);
    _polish1  = _c(p?.costPolish1);
    _polish2  = _c(p?.costPolish2);
    _spinner1 = _c(p?.costSpinner1);
    _spinner2 = _c(p?.costSpinner2);
  }

  TextEditingController _c(double? v) =>
      TextEditingController(text: (v != null && v > 0) ? v.toString() : '');

  @override
  void dispose() {
    for (final c in [_name, _category, _padii, _weightG, _sellPrice,
        _material, _plasma, _labour1, _labour2, _labour3, _labour4,
        _vettu1, _vettu2, _welding1, _welding2, _runner1, _runner2,
        _varai, _polish1, _polish2, _spinner1, _spinner2]) c.dispose();
    super.dispose();
  }

  double _v(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  // Total cost per piece
  double get _totalCost =>
      _v(_material)  + _v(_plasma)   +
      _v(_labour1)   + _v(_labour2)  + _v(_labour3)  + _v(_labour4)  +
      _v(_vettu1)    + _v(_vettu2)   +
      _v(_welding1)  + _v(_welding2) +
      _v(_runner1)   + _v(_runner2)  +
      _v(_varai)     +
      _v(_polish1)   + _v(_polish2)  +
      _v(_spinner1)  + _v(_spinner2);

  // Live profit preview
  double get _profitPreview {
    final wg   = int.tryParse(_weightG.text) ?? 1;
    final sell = double.tryParse(_sellPrice.text) ?? 0;
    // costPerKg = totalCostPerProduct * (1000 / weightG)
    final cpk  = _totalCost * (1000.0 / wg);
    final ppk  = sell - cpk;
    return _soldByPiece ? ppk * (wg / 1000.0) : ppk;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final product = Product(
      id:             widget.product?.id,
      name:           _name.text.trim(),
      category:       _category.text.trim(),
      padii:          _padii.text.trim(),
      productWeightG: int.tryParse(_weightG.text) ?? 0,
      sellPricePerKg: double.tryParse(_sellPrice.text) ?? 0,
      soldByPiece:    _soldByPiece,
      unit:           _soldByPiece ? 'pcs' : 'kg',
      costMaterial:   _v(_material),
      costPlasma:     _v(_plasma),
      costLabour1:    _v(_labour1),
      costLabour2:    _v(_labour2),
      costLabour3:    _v(_labour3),
      costLabour4:    _v(_labour4),
      costVettu1:     _v(_vettu1),
      costVettu2:     _v(_vettu2),
      costWelding1:   _v(_welding1),
      costWelding2:   _v(_welding2),
      costRunner1:    _v(_runner1),
      costRunner2:    _v(_runner2),
      costVarai:      _v(_varai),
      costPolish1:    _v(_polish1),
      costPolish2:    _v(_polish2),
      costSpinner1:   _v(_spinner1),
      costSpinner2:   _v(_spinner2),
    );

    await FirebaseService.instance.saveProduct(product);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final fmt      = NumberFormat('#,##0.00', 'en_IN');
    final isEdit   = widget.product != null;
    final profitOk = _profitPreview >= 0;
    final profitColor = profitOk ? const Color(0xFF1A6B2A) : Colors.red;
    final profitBg    = profitOk ? const Color(0xFFC6EFCE) : const Color(0xFFFFCCCC);
    final wgLabel = _weightG.text.isEmpty ? 'piece' : '${_weightG.text}g';

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Product' : 'New Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Product Info ───────────────────────────────────────────────
            _sectionHeader('Product Info'),
            _tf(_name,     'Product name *',                     required: true),
            _tf(_category, 'Category (SS / Brass / custom) *',   required: true),
            _tf(_padii,    'Padii / size label',  hint: 'e.g. 1½ padii'),
            _tf(_weightG,  'Weight per piece (grams) *',
                type: TextInputType.number, required: true, suffix: 'g'),
            _tf(_sellPrice,'Selling price per kg *',
                type: TextInputType.number, required: true, suffix: 'Rs/kg'),

            // Sold by piece toggle
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sold by piece?',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(_soldByPiece
                      ? 'Profit calculated per piece'
                      : 'Profit calculated per kg (default)',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
                ])),
                Switch(value: _soldByPiece,
                    onChanged: (v) => setState(() => _soldByPiece = v),
                    activeColor: const Color(0xFF1F4E79)),
              ]),
            ),

            // ── Cost Breakdown ─────────────────────────────────────────────
            _sectionHeader('Cost Breakdown — per $wgLabel'),

            // Material & Plasma (single each)
            Row(children: [
              Expanded(child: _tf(_material, 'Material', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_plasma,   'Plasma',   type: TextInputType.number)),
            ]),

            // Labour 1, 2
            _subHeader('Labour'),
            Row(children: [
              Expanded(child: _tf(_labour1, 'Labour 1', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_labour2, 'Labour 2', type: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: _tf(_labour3, 'Labour 3', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_labour4, 'Labour 4', type: TextInputType.number)),
            ]),

            // Vettu 1, 2
            _subHeader('Vettu'),
            Row(children: [
              Expanded(child: _tf(_vettu1, 'Vettu 1', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_vettu2, 'Vettu 2', type: TextInputType.number)),
            ]),

            // Welding 1, 2
            _subHeader('Welding'),
            Row(children: [
              Expanded(child: _tf(_welding1, 'Welding 1', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_welding2, 'Welding 2', type: TextInputType.number)),
            ]),

            // Runner 1, 2
            _subHeader('Runner'),
            Row(children: [
              Expanded(child: _tf(_runner1, 'Runner 1', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_runner2, 'Runner 2', type: TextInputType.number)),
            ]),

            // Varai (single)
            _subHeader('Varai'),
            _tf(_varai, 'Varai', type: TextInputType.number),

            // Polish 1, 2
            _subHeader('Polish'),
            Row(children: [
              Expanded(child: _tf(_polish1, 'Polish 1', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_polish2, 'Polish 2', type: TextInputType.number)),
            ]),

            // Spinner 1, 2
            _subHeader('Spinner'),
            Row(children: [
              Expanded(child: _tf(_spinner1, 'Spinner 1', type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _tf(_spinner2, 'Spinner 2', type: TextInputType.number)),
            ]),

            const SizedBox(height: 4),

            // ── Profit preview ─────────────────────────────────────────────
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
                if (_weightG.text.isNotEmpty) ...[
                  Row(children: [
                    const Text('Cost per kg:'),
                    const Spacer(),
                    Text('Rs ${fmt.format(_totalCost * (1000.0 / (int.tryParse(_weightG.text) ?? 1)))}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 4),
                ],
                const Divider(height: 12),
                Row(children: [
                  Text('Net profit per ${_soldByPiece ? "piece" : "kg"}:',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('Rs ${fmt.format(_profitPreview)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: profitColor)),
                ]),
                const SizedBox(height: 4),
                Text(
                  _soldByPiece
                    ? 'Piece profit = (sell/kg - cost/kg) × ${_weightG.text.isEmpty ? "weight" : "${_weightG.text}"}g/1000'
                    : 'Profit/kg = sell price − (total cost × 1000g ÷ ${_weightG.text.isEmpty ? "weight" : "${_weightG.text}g"})',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),

            // ── Save ──────────────────────────────────────────────────────
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

  Widget _subHeader(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 2),
    child: Text(text, style: const TextStyle(fontSize: 12,
        fontWeight: FontWeight.w600, color: Color(0xFF555555))));

  Widget _tf(TextEditingController ctrl, String label,
      {bool required = false, String? hint, String? suffix,
       TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label, hintText: hint, suffixText: suffix,
          filled: true, fillColor: const Color(0xFFF5F6FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      ),
    );
  }
}