// lib/screens/weight_split_screen.dart
// Weight Split — distribute one measured total weight across several products
// whose per-piece weight is only approximate (e.g. 400 g piece may really be
// 400–420 g). The split always adds up to the measured total EXACTLY.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/firebase_service.dart';

const _kPrimary = Color(0xFF1F4E79);

// ══════════════════════════════════════════════════════════════════════════════
// PURE CALCULATION LAYER
// ══════════════════════════════════════════════════════════════════════════════

/// One product line the user typed in.
class SplitItem {
  final String name;
  final int pieces;
  final double minG; // approximate weight per piece
  final double maxG; // realistic upper limit per piece

  const SplitItem({
    required this.name,
    required this.pieces,
    required this.minG,
    required this.maxG,
  });
}

/// One computed line of the result table.
class SplitLine {
  final String name;
  final int pieces;
  final double approxG;
  final int totalG; // integer grams -> the table can never drift
  final bool outOfRange; // avg landed outside the approx..max band

  const SplitLine({
    required this.name,
    required this.pieces,
    required this.approxG,
    required this.totalG,
    required this.outOfRange,
  });

  double get avgG => pieces == 0 ? approxG : totalG / pieces;
  double get totalKg => totalG / 1000.0;
}

/// Deterministic 0.75–1.25 multiplier from a seed string. Used instead of
/// `Random` so the same inputs always reproduce the same table, while the
/// "Regenerate" button (which changes [salt]) gives a different realistic mix.
///
/// FNV-1a plus an avalanche finish — a plain `h * 31 + c` hash leaves products
/// with similar names ('A' / 'B') on almost the same multiplier, which quietly
/// degrades the whole split back into a flat proportional one.
double _jitter(String seed, int salt, int index) {
  const mask = 0xFFFFFFFF;
  int h = (0x811C9DC5 ^ (salt * 0x9E3779B1) ^ (index * 0x85EBCA77)) & mask;
  for (final c in seed.codeUnits) {
    h = ((h ^ c) * 0x01000193) & mask;
  }
  h ^= h >> 15;
  h = (h * 0x2545F491) & mask;
  h ^= h >> 13;
  h = (h * 0x85EBCA6B) & mask;
  h ^= h >> 16;
  return 0.75 + (h % 1000) / 1000.0 * 0.5;
}

/// Splits [totalG] grams across [items].
///
/// * Every piece stays inside its own approx..max band whenever the measured
///   total makes that possible.
/// * The extra weight is NOT spread as a flat proportion — each product gets a
///   jittered share, then the shares are rebalanced until they add up.
/// * Per-piece averages are snapped to 0.5 g steps (what a real weighing gives)
///   and the leftover grams are spread across the big lines, so
///   `sum(totalG) == totalG` exactly.
List<SplitLine> distributeWeight({
  required int totalG,
  required List<SplitItem> items,
  int salt = 0,
}) {
  final n = items.length;
  final grams = List<double>.filled(n, 0);
  final active = <int>[
    for (var i = 0; i < n; i++)
      if (items[i].pieces > 0) i
  ];

  if (active.isEmpty || totalG <= 0) {
    return [
      for (final it in items)
        SplitLine(
          name: it.name,
          pieces: it.pieces,
          approxG: it.minG,
          totalG: 0,
          outOfRange: false,
        )
    ];
  }

  double minTotal = 0, maxTotal = 0;
  for (final i in active) {
    minTotal += items[i].pieces * items[i].minG;
    maxTotal += items[i].pieces * items[i].maxG;
  }

  final bounded = totalG > minTotal && totalG < maxTotal;

  if (totalG <= minTotal) {
    // Measured total is below even the approximate weights — scale everything
    // down, keeping the same relative sizes (with a light natural wobble).
    double denom = 0;
    final share = <int, double>{};
    for (final i in active) {
      final s = items[i].pieces *
          items[i].minG *
          (0.97 + (_jitter(items[i].name, salt, i) - 0.75) * 0.12);
      share[i] = s;
      denom += s;
    }
    for (final i in active) {
      grams[i] = totalG * (share[i]! / denom);
    }
  } else if (totalG >= maxTotal) {
    // Above the realistic ceiling — everyone sits at max, the surplus is shared.
    double denom = 0;
    final share = <int, double>{};
    for (final i in active) {
      final s = items[i].pieces *
          items[i].maxG *
          (0.97 + (_jitter(items[i].name, salt, i) - 0.75) * 0.12);
      share[i] = s;
      denom += s;
    }
    final surplus = totalG - maxTotal;
    for (final i in active) {
      grams[i] = items[i].pieces * items[i].maxG + surplus * (share[i]! / denom);
    }
  } else {
    // Normal case — fill each band by a jittered fraction, then rebalance the
    // fractions until the assigned extra matches the measured extra exactly.
    final cap = <int, double>{}; // grams of headroom per product
    for (final i in active) {
      cap[i] = items[i].pieces * (items[i].maxG - items[i].minG);
    }
    final capTotal = cap.values.fold<double>(0, (s, x) => s + x);
    final extra = totalG - minTotal;
    final baseF = capTotal > 0 ? extra / capTotal : 0.0;

    final f = <int, double>{};
    for (final i in active) {
      f[i] = (baseF * _jitter(items[i].name, salt, i)).clamp(0.0, 1.0);
    }

    for (var pass = 0; pass < 40; pass++) {
      double assigned = 0;
      for (final i in active) {
        assigned += cap[i]! * f[i]!;
      }
      final diff = extra - assigned;
      if (diff.abs() < 1e-6) break;

      double headroom = 0;
      for (final i in active) {
        headroom += diff > 0 ? cap[i]! * (1 - f[i]!) : cap[i]! * f[i]!;
      }
      if (headroom <= 1e-9) break;

      for (final i in active) {
        if (cap[i]! <= 0) continue;
        final h = diff > 0 ? cap[i]! * (1 - f[i]!) : cap[i]! * f[i]!;
        f[i] = (f[i]! + (diff * (h / headroom)) / cap[i]!).clamp(0.0, 1.0);
      }
    }

    for (final i in active) {
      grams[i] = items[i].pieces * items[i].minG + cap[i]! * f[i]!;
    }
  }

  // ── Snap per-piece averages to 0.5 g, then fix the rounding leftover ───────
  const step = 0.5;
  final gInt = List<int>.filled(n, 0);
  final lower = List<int>.filled(n, 0);
  final upper = List<int>.filled(n, 0);

  for (final i in active) {
    final it = items[i];
    var avg = grams[i] / it.pieces;
    avg = (avg / step).round() * step;
    if (bounded) avg = avg.clamp(it.minG, it.maxG);
    gInt[i] = (avg * it.pieces).round();
    lower[i] = (it.pieces * it.minG).round();
    upper[i] = (it.pieces * it.maxG).round();
  }

  var residual = totalG - gInt.fold<int>(0, (s, x) => s + x);
  if (residual != 0) {
    final order = [...active]
      ..sort((a, b) => items[b].pieces.compareTo(items[a].pieces));
    var guard = 0;
    while (residual != 0 && guard < 5000) {
      var moved = false;
      for (final i in order) {
        if (residual == 0) break;
        // ~0.05 g per piece per pass — keeps the correction invisible.
        final chunk = math.max(1, (items[i].pieces / 20).round());
        var stepG = residual > 0
            ? math.min(residual, chunk)
            : math.max(residual, -chunk);
        var next = gInt[i] + stepG;
        if (bounded) next = next.clamp(lower[i], upper[i]);
        if (next != gInt[i]) {
          residual -= next - gInt[i];
          gInt[i] = next;
          moved = true;
        }
      }
      guard++;
      if (!moved) break; // every line is pinned at its limit
    }
    if (residual != 0) {
      // Bands cannot absorb it — the biggest line takes the remainder so the
      // grand total still matches the measured weight exactly.
      gInt[order.first] += residual;
    }
  }

  return [
    for (var i = 0; i < n; i++)
      SplitLine(
        name: items[i].name,
        pieces: items[i].pieces,
        approxG: items[i].minG,
        totalG: gInt[i],
        outOfRange: items[i].pieces > 0 &&
            (gInt[i] / items[i].pieces < items[i].minG - 0.01 ||
                gInt[i] / items[i].pieces > items[i].maxG + 0.01),
      )
  ];
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class WeightSplitScreen extends StatefulWidget {
  const WeightSplitScreen({super.key});
  @override
  State<WeightSplitScreen> createState() => _WeightSplitScreenState();
}

class _WeightSplitScreenState extends State<WeightSplitScreen> {
  final _totalCtrl = TextEditingController();
  final List<_RowData> _rows = [];
  List<SplitLine> _result = [];
  int _salt = 0;
  String? _error;

  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _rows.add(_RowData());
    _loadProducts();
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final p = await FirebaseService.instance.getProducts();
      if (mounted) setState(() => _products = p);
    } catch (_) {
      // Offline / not signed in — manual entry still works.
    }
  }

  // ── Input helpers ──────────────────────────────────────────────────────────
  double _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;

  void _addRow() => setState(() => _rows.add(_RowData()));

  void _removeRow(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
      if (_rows.isEmpty) _rows.add(_RowData());
      _result = [];
    });
  }

  Future<void> _pickProduct(int i) async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved products found')),
      );
      return;
    }
    final p = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductPicker(products: _products),
    );
    if (p == null) return;
    setState(() {
      _rows[i].name.text = p.name;
      _rows[i].minG.text = p.productWeightG.toString();
      _rows[i].maxG.text = _defaultMax(p.productWeightG.toDouble());
      _result = [];
    });
  }

  /// Default realistic ceiling — 5 % over the approximate weight, rounded to
  /// the nearest 5 g (400 → 420, 300 → 315, 200 → 210). Always editable.
  String _defaultMax(double minG) {
    if (minG <= 0) return '';
    final v = (minG * 1.05 / 5).round() * 5;
    return v.toString();
  }

  // ── Calculate ──────────────────────────────────────────────────────────────
  void _calculate({bool regenerate = false}) {
    FocusScope.of(context).unfocus();
    final totalKg = _d(_totalCtrl);
    if (totalKg <= 0) {
      setState(() {
        _error = 'Enter the measured total weight in kg';
        _result = [];
      });
      return;
    }

    final items = <SplitItem>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      final pieces = int.tryParse(r.pieces.text.trim()) ?? 0;
      final minG = _d(r.minG);
      if (name.isEmpty && pieces == 0 && minG == 0) continue;
      if (minG <= 0) {
        setState(() {
          _error = 'Enter the approx g/piece for '
              '${name.isEmpty ? "every product" : name}';
          _result = [];
        });
        return;
      }
      var maxG = _d(r.maxG);
      if (maxG < minG) maxG = minG;
      items.add(SplitItem(
        name: name.isEmpty ? 'Product ${items.length + 1}' : name,
        pieces: pieces,
        minG: minG,
        maxG: maxG,
      ));
    }

    if (items.isEmpty || items.every((e) => e.pieces == 0)) {
      setState(() {
        _error = 'Add at least one product with pieces';
        _result = [];
      });
      return;
    }

    setState(() {
      _error = null;
      if (regenerate) _salt++;
      _result = distributeWeight(
        totalG: (totalKg * 1000).round(),
        items: items,
        salt: _salt,
      );
    });
  }

  void _copyResult() {
    final kg = NumberFormat('#,##0.000');
    final b = StringBuffer();
    b.writeln('Total measured: ${kg.format(_resultTotalG / 1000)} kg');
    b.writeln('');
    for (final l in _result) {
      if (l.pieces == 0) continue;
      b.writeln('${l.name} — ${l.pieces} pcs × '
          '${l.avgG.toStringAsFixed(1)} g = ${kg.format(l.totalKg)} kg');
    }
    Clipboard.setData(ClipboardData(text: b.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  int get _resultTotalG => _result.fold<int>(0, (s, l) => s + l.totalG);

  // ── Live range preview ─────────────────────────────────────────────────────
  (double, double) get _rangeKg {
    double lo = 0, hi = 0;
    for (final r in _rows) {
      final pieces = int.tryParse(r.pieces.text.trim()) ?? 0;
      final minG = _d(r.minG);
      var maxG = _d(r.maxG);
      if (maxG < minG) maxG = minG;
      lo += pieces * minG;
      hi += pieces * maxG;
    }
    return (lo / 1000, hi / 1000);
  }

  @override
  Widget build(BuildContext context) {
    final (lo, hi) = _rangeKg;
    final totalKg = _d(_totalCtrl);
    final kg3 = NumberFormat('#,##0.000');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Split'),
        actions: [
          if (_result.isNotEmpty)
            IconButton(
              tooltip: 'Another realistic split',
              icon: const Icon(Icons.casino_outlined),
              onPressed: () => _calculate(regenerate: true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          // ── Measured total ────────────────────────────────────────────────
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Measured total weight',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: _kPrimary)),
              const SizedBox(height: 10),
              TextField(
                controller: _totalCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  suffixText: 'kg',
                  hintText: '0.000',
                  filled: true,
                  fillColor: const Color(0xFFF5F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (lo > 0) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.straighten, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Realistic range: ${kg3.format(lo)} – ${kg3.format(hi)} kg',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ]),
                if (totalKg > 0 && (totalKg < lo - 0.0005 || totalKg > hi + 0.0005))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          totalKg < lo
                              ? 'Total is below the range — averages will fall under the approx weight.'
                              : 'Total is above the range — averages will go over the max weight.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ]),
                  ),
              ],
            ]),
          ),

          // ── Products ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Row(children: [
              const Text('Products',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add product'),
              ),
            ]),
          ),

          for (var i = 0; i < _rows.length; i++) _rowCard(i),

          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _calculate,
              icon: const Icon(Icons.balance),
              label: const Text('Calculate split',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ),

          if (_result.isNotEmpty) ...[
            const SizedBox(height: 20),
            _resultCard(kg3),
          ],
        ],
      ),
    );
  }

  // ── Widgets ────────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

  Widget _rowCard(int i) {
    final r = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: r.name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Product name',
                  border: UnderlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Pick saved product',
              icon: const Icon(Icons.inventory_2_outlined,
                  size: 20, color: _kPrimary),
              onPressed: () => _pickProduct(i),
            ),
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.close, size: 20, color: Colors.red.shade300),
              onPressed: () => _removeRow(i),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _numField(r.pieces, 'Pieces', null)),
            const SizedBox(width: 10),
            Expanded(
              child: _numField(r.minG, 'Approx g/pc', 'g', decimal: true,
                  onChanged: (v) {
                if (r.maxG.text.isEmpty) {
                  r.maxG.text = _defaultMax(double.tryParse(v) ?? 0);
                }
              }),
            ),
            const SizedBox(width: 10),
            Expanded(child: _numField(r.maxG, 'Max g/pc', 'g', decimal: true)),
          ]),
        ]),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, String? suffix,
      {bool decimal = false, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (v) {
        onChanged?.call(v);
        setState(() {});
      },
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        suffixText: suffix,
        labelStyle: const TextStyle(fontSize: 13),
        border: const UnderlineInputBorder(),
      ),
    );
  }

  Widget _resultCard(NumberFormat kg3) {
    final target = (_d(_totalCtrl) * 1000).round();
    final matches = target == _resultTotalG;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Split result',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _kPrimary)),
          const Spacer(),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18, color: _kPrimary),
            onPressed: _copyResult,
          ),
        ]),
        const SizedBox(height: 6),

        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F1FB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(children: [
            Expanded(flex: 4, child: _Hdr('Product')),
            Expanded(flex: 2, child: _Hdr('Pcs', right: true)),
            Expanded(flex: 3, child: _Hdr('g/pc', right: true)),
            Expanded(flex: 3, child: _Hdr('kg', right: true)),
          ]),
        ),

        for (final l in _result)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
            child: Row(children: [
              Expanded(
                flex: 4,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.name,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600)),
                      Text('approx ${l.approxG.toStringAsFixed(0)} g',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black45)),
                    ]),
              ),
              Expanded(
                  flex: 2,
                  child: Text('${l.pieces}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13.5))),
              Expanded(
                flex: 3,
                child: Text(
                  l.pieces == 0 ? '—' : l.avgG.toStringAsFixed(1),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: l.outOfRange ? Colors.orange.shade800 : Colors.black87,
                  ),
                ),
              ),
              Expanded(
                  flex: 3,
                  child: Text(kg3.format(l.totalKg),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700))),
            ]),
          ),

        const Divider(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            const Expanded(
              flex: 6,
              child: Text('TOTAL',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                  '${_result.fold<int>(0, (s, l) => s + l.pieces)} pcs',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
            Expanded(
              flex: 3,
              child: Text(kg3.format(_resultTotalG / 1000),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _kPrimary)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(matches ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: matches ? Colors.green.shade600 : Colors.red.shade600),
          const SizedBox(width: 6),
          Text(
            matches
                ? 'Matches the measured total exactly'
                : 'Off by ${(target - _resultTotalG)} g',
            style: TextStyle(
                fontSize: 12,
                color: matches ? Colors.green.shade700 : Colors.red.shade700),
          ),
        ]),
      ]),
    );
  }
}

class _Hdr extends StatelessWidget {
  final String text;
  final bool right;
  const _Hdr(this.text, {this.right = false});
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: _kPrimary),
      );
}

class _RowData {
  final TextEditingController name = TextEditingController();
  final TextEditingController pieces = TextEditingController();
  final TextEditingController minG = TextEditingController();
  final TextEditingController maxG = TextEditingController();

  void dispose() {
    name.dispose();
    pieces.dispose();
    minG.dispose();
    maxG.dispose();
  }
}

// ── Saved-product picker ─────────────────────────────────────────────────────
class _ProductPicker extends StatefulWidget {
  final List<Product> products;
  const _ProductPicker({required this.products});
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.products
        .where((p) => p.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          const SizedBox(height: 12),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Search product',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = list[i];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.category} • ${p.productWeightG} g'),
                  onTap: () => Navigator.pop(context, p),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}
