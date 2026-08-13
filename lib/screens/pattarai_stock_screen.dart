// lib/screens/pattarai_stock_screen.dart
// Sheet / Wastage — tracks the sheet sent out to each pattarai, the pieces that
// come back, and the wastage settled in bulk every month or two.
//
// Only wastage comes off company stock; sending sheet out and taking pieces
// back are internal movements. See PattaraiStockTx in models.dart.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/app_toast.dart';
import '../services/firebase_service.dart';

const _kPrimary = Color(0xFF1F4E79);
const _kWaste = Color(0xFFB3261E);

class PattaraiStockScreen extends StatefulWidget {
  const PattaraiStockScreen({super.key});
  @override
  State<PattaraiStockScreen> createState() => _PattaraiStockScreenState();
}

class _PattaraiStockScreenState extends State<PattaraiStockScreen> {
  // Resolved lazily — reading FirebaseService in a field initializer throws
  // before Firebase.initializeApp() and takes the whole screen down.
  FirebaseService get _svc => FirebaseService.instance;
  final _fmt = NumberFormat('#,##0.00');

  List<Pattarai> _pattarais = [];
  List<PattaraiStockTx> _txs = [];
  List<WastageSale> _wastageSales = [];
  bool _loading = true;
  String? _error;
  MaterialMetal _metal = MaterialMetal.ss;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        _svc.getPattarais(),
        _svc.getPattaraiStockTxs(),
        _svc.getWastageSales(),
      ]);
      if (!mounted) return;
      setState(() {
        _pattarais = r[0] as List<Pattarai>;
        _txs = r[1] as List<PattaraiStockTx>;
        _wastageSales = r[2] as List<WastageSale>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Shown in the body, NOT via a snackbar: _load() runs from initState,
      // and a synchronous failure would reach ScaffoldMessenger.of(context)
      // before initState finished — which crashes the whole screen.
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  List<PattaraiStockTx> get _metalTxs =>
      _txs.where((t) => t.materialType.metal == _metal).toList();

  List<PattaraiBalance> get _balances =>
      computePattaraiBalances(_txs, metal: _metal);

  Future<void> _addEntry(PattaraiTxType type, {PattaraiBalance? forBalance}) async {
    if (_pattarais.isEmpty) {
      _snack('Create a pattarai first — Settings → shop name');
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EntrySheet(
        type: type,
        metal: _metal,
        pattarais: _pattarais,
        presetPattaraiId: forBalance?.pattaraiId,
        suggestedKg: type == PattaraiTxType.wastage
            ? forBalance?.outstanding
            : null,
      ),
    );
    if (saved == true) _load();
  }

  // ── Pattarai list: add / rename / remove ───────────────────────────────────
  Future<void> _managePattarais() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Pattarais',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Each pattarai keeps its own sheet and wastage account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            if (_pattarais.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('None yet.',
                    style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              ..._pattarais.map((p) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.storefront_outlined,
                        color: _kPrimary, size: 20),
                    title: Text(p.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () async {
                          final name = await _askName(initial: p.name);
                          if (name == null) return;
                          try {
                            await _svc.savePattarai(Pattarai(
                              id: p.id,
                              name: name,
                              isActive: p.isActive,
                              sortOrder: p.sortOrder,
                            ));
                            await _load();
                            setSheet(() {});
                          } catch (e) {
                            _snack('Could not rename: $e');
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: Colors.red.shade300),
                        onPressed: () => _removePattarai(p, setSheet),
                      ),
                    ]),
                  )),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add pattarai'),
                onPressed: () async {
                  final name = await _askName();
                  if (name == null) return;
                  try {
                    await _svc.savePattarai(Pattarai(
                      name: name,
                      sortOrder: _pattarais.length,
                    ));
                    await _load();
                    setSheet(() {});
                    _snack('$name added');
                  } catch (e) {
                    _snack('Could not add pattarai: $e');
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// No TextEditingController here on purpose. Disposing one right after
  /// showDialog() returns crashes: the dialog is still playing its exit
  /// animation and rebuilds the field against the dead controller.
  /// TextFormField.initialValue + onChanged needs no controller at all.
  Future<String?> _askName({String initial = ''}) async {
    var value = initial;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? 'New pattarai' : 'Rename pattarai'),
        content: TextFormField(
          initialValue: initial,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Pattarai 1'),
          onChanged: (v) => value = v,
          onFieldSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, value.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    return (name == null || name.isEmpty) ? null : name;
  }

  Future<void> _removePattarai(Pattarai p, StateSetter setSheet) async {
    // Refuse while it still holds history — deleting would orphan the ledger.
    final used = _txs.any((t) => t.pattaraiId == (p.id ?? p.name));
    if (used) {
      _snack('${p.name} has sheet/wastage entries — delete those first');
      return;
    }
    if (_pattarais.length <= 1) {
      _snack('Keep at least one pattarai');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${p.name}?'),
        content: const Text('This only removes the name from the list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || p.id == null) return;
    await _svc.deletePattarai(p.id!);
    await _load();
    setSheet(() {});
  }

  Future<void> _delete(PattaraiStockTx tx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${tx.type.label.toLowerCase()}?'),
        content: Text(
          '${tx.pattaraiName} — ${_fmt.format(tx.quantityKg)} kg '
          '${tx.materialType.metal.displayName}\n\n'
          '${tx.type == PattaraiTxType.wastage ? 'This will also put the material back into company stock.' : 'The pattarai balance will be adjusted.'}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.deletePattaraiStockTx(tx);
      _snack('Deleted');
      _load();
    } catch (e) {
      _snack('Could not delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Sheet / Wastage'),
        actions: [
          IconButton(
            tooltip: 'Manage pattarais',
            icon: const Icon(Icons.store_outlined),
            onPressed: _managePattarais,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Could not load records: $_error',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.orange.shade900)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _metalSelector(),
                  const SizedBox(height: 14),
                  _summaryCard(),
                  const SizedBox(height: 12),
                  _wastageStoreCard(),
                  const SizedBox(height: 18),
                  const Text('Pattarai balances',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  if (_balances.isEmpty)
                    _empty('No sheet sent out yet for '
                        '${_metal.displayName}.\nTap "Send sheet" below.')
                  else
                    ..._balances.map(_balanceCard),
                  const SizedBox(height: 18),
                  const Text('Recent entries',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black54)),
                  const SizedBox(height: 8),
                  if (_metalTxs.isEmpty)
                    _empty('Nothing recorded yet.')
                  else
                    ..._metalTxs.take(40).map(_txTile),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(children: [
            Expanded(
              child: _actionBtn('Send sheet', Icons.north_east, _kPrimary,
                  () => _addEntry(PattaraiTxType.issue)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionBtn('Pieces back', Icons.south_west,
                  const Color(0xFF1A6B2A), () => _addEntry(PattaraiTxType.pieces)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionBtn('Wastage', Icons.delete_outline, _kWaste,
                  () => _addEntry(PattaraiTxType.wastage)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _actionBtn(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      SizedBox(
        height: 46,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _metalSelector() => Row(children: [
        for (final m in MaterialMetal.values) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _metal = m),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _metal == m ? _kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _metal == m ? _kPrimary : Colors.grey.shade300),
                ),
                child: Text(m.chipLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _metal == m ? Colors.white : Colors.grey.shade700,
                    )),
              ),
            ),
          ),
          if (m != MaterialMetal.values.last) const SizedBox(width: 8),
        ]
      ]);

  Widget _summaryCard() {
    final all = _balances;
    final issued = all.fold<double>(0, (s, b) => s + b.issued);
    final back = all.fold<double>(0, (s, b) => s + b.piecesBack);
    final waste = all.fold<double>(0, (s, b) => s + b.wastage);
    final out = issued - back - waste;
    final pct = issued > 0 ? (waste / issued) * 100 : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_metal.displayName} — all pattarais',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        _sumRow('Sheet sent out', issued, Colors.white),
        _sumRow('Pieces received', back, Colors.greenAccent),
        _sumRow('Wastage settled', waste, Colors.orangeAccent),
        const Divider(color: Colors.white24, height: 18),
        _sumRow('Still with pattarai', out,
            out < -0.01 ? Colors.red.shade300 : Colors.white, bold: true),
        if (pct != null) ...[
          const SizedBox(height: 6),
          Text('Wastage is ${pct.toStringAsFixed(1)}% of the sheet sent out',
              style: const TextStyle(color: Colors.white54, fontSize: 11.5)),
        ],
      ]),
    );
  }

  Widget _sumRow(String label, double kg, Color color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: bold ? 13.5 : 12.5,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
          Text('${_fmt.format(kg)} kg',
              style: TextStyle(
                  color: color,
                  fontSize: bold ? 16 : 13.5,
                  fontWeight: FontWeight.bold)),
        ]),
      );

  // ── Wastage in store: collected scrap, waiting to be sold ─────────────────
  Widget _wastageStoreCard() {
    final inStore = wastageInStore(_txs, _wastageSales, metal: _metal);
    final income = wastageSaleIncome(_wastageSales, metal: _metal);
    final sold = _wastageSales.where((s) => s.materialType.metal == _metal);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0D6D3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.recycling, color: _kWaste, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wastage in store',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Scrap collected, waiting to be sold',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ]),
          ),
          Text('${_fmt.format(inStore)} kg',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: inStore < -0.01 ? Colors.red : _kWaste,
              )),
        ]),
        if (sold.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Sold so far: ${_fmt.format(sold.fold<double>(0, (s, x) => s + x.quantityKg))} kg '
            '• earned ₹${NumberFormat('#,##0', 'en_IN').format(income)}',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _kWaste,
              side: const BorderSide(color: _kWaste),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            onPressed: inStore <= 0 && sold.isEmpty ? null : _sellWastage,
            icon: const Icon(Icons.sell_outlined, size: 16),
            label: const Text('Sell wastage',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),
        if (sold.isNotEmpty) ...[
          const Divider(height: 20),
          ...sold.take(6).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${DateFormat('dd MMM yy').format(s.date)}'
                      '${s.buyerName.isEmpty ? '' : ' • ${s.buyerName}'}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ),
                  Text(
                    '${_fmt.format(s.quantityKg)} kg · '
                    '₹${NumberFormat('#,##0', 'en_IN').format(s.amount)}',
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close,
                        size: 15, color: Colors.red.shade300),
                    onPressed: () => _deleteWastageSale(s),
                  ),
                ]),
              )),
        ],
      ]),
    );
  }

  Future<void> _sellWastage() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SellWastageSheet(
        metal: _metal,
        inStore: wastageInStore(_txs, _wastageSales, metal: _metal),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteWastageSale(WastageSale s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wastage sale?'),
        content: Text('${_fmt.format(s.quantityKg)} kg — the scrap goes back '
            'into the wastage store.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || s.id == null) return;
    try {
      await _svc.deleteWastageSale(s.id!);
      _load();
    } catch (e) {
      _snack('Could not delete: $e');
    }
  }

  Widget _balanceCard(PattaraiBalance b) {
    final out = b.outstanding;
    final pct = b.wastagePercent;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: Text(b.pattaraiName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fmt.format(out)} kg',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: out < -0.01
                        ? Colors.red
                        : (out.abs() < 0.01
                            ? Colors.grey
                            : Colors.orange.shade800),
                  )),
              Text(
                out < -0.01
                    ? 'more came back than sent'
                    : (out.abs() < 0.01 ? 'fully settled' : 'still pending'),
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _chip('Sent', b.issued, Colors.blueGrey),
            const SizedBox(width: 6),
            _chip('Back', b.piecesBack, const Color(0xFF1A6B2A)),
            const SizedBox(width: 6),
            _chip('Waste', b.wastage, _kWaste),
          ]),
          if (pct != null && b.wastage > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Wastage ${(pct * 100).toStringAsFixed(1)}%',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ),
          ],
          if (out > 0.01) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: _kWaste,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () =>
                    _addEntry(PattaraiTxType.wastage, forBalance: b),
                icon: const Icon(Icons.playlist_add_check, size: 16),
                label: Text('Settle ${_fmt.format(out)} kg as wastage',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _chip(String label, double kg, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
            const SizedBox(height: 2),
            Text('${_fmt.format(kg)} kg',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ]),
        ),
      );

  Widget _txTile(PattaraiStockTx tx) {
    final isIssue = tx.type == PattaraiTxType.issue;
    final color = switch (tx.type) {
      PattaraiTxType.issue => _kPrimary,
      PattaraiTxType.pieces => const Color(0xFF1A6B2A),
      PattaraiTxType.wastage => _kWaste,
    };
    final icon = switch (tx.type) {
      PattaraiTxType.issue => Icons.north_east,
      PattaraiTxType.pieces => Icons.south_west,
      PattaraiTxType.wastage => Icons.delete_outline,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 22),
        title: Text('${tx.type.label} — ${tx.pattaraiName}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy').format(tx.date)}'
          '${tx.note.isEmpty ? '' : ' • ${tx.note}'}'
          '${tx.type == PattaraiTxType.wastage ? ' • off company stock' : ''}',
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${isIssue ? '+' : '−'}${_fmt.format(tx.quantityKg)} kg',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13.5, color: color)),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.red.shade300),
            onPressed: () => _delete(tx),
          ),
        ]),
      ),
    );
  }

  Widget _empty(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEEEEEE))),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// Entry sheet — send sheet / pieces back / wastage
// ══════════════════════════════════════════════════════════════════════════════
class _EntrySheet extends StatefulWidget {
  final PattaraiTxType type;
  final MaterialMetal metal;
  final List<Pattarai> pattarais;
  final String? presetPattaraiId;
  final double? suggestedKg;

  const _EntrySheet({
    required this.type,
    required this.metal,
    required this.pattarais,
    this.presetPattaraiId,
    this.suggestedKg,
  });

  @override
  State<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<_EntrySheet> {
  // Resolved lazily — reading FirebaseService in a field initializer throws
  // before Firebase.initializeApp() and takes the whole screen down.
  FirebaseService get _svc => FirebaseService.instance;
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late MaterialMetal _metal;
  late String _pattaraiId;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _metal = widget.metal;
    _pattaraiId = widget.presetPattaraiId ??
        (widget.pattarais.first.id ?? widget.pattarais.first.name);
    final s = widget.suggestedKg;
    if (s != null && s > 0) _qtyCtrl.text = s.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Pattarai get _pattarai => widget.pattarais.firstWhere(
        (p) => (p.id ?? p.name) == _pattaraiId,
        orElse: () => widget.pattarais.first,
      );

  Color get _color => switch (widget.type) {
        PattaraiTxType.issue => _kPrimary,
        PattaraiTxType.pieces => const Color(0xFF1A6B2A),
        PattaraiTxType.wastage => _kWaste,
      };

  String get _explain => switch (widget.type) {
        PattaraiTxType.issue =>
          'Sheet going out to the pattarai. Company stock stays the same — '
              'the material is still yours, just at the workshop.',
        PattaraiTxType.pieces =>
          'Finished pieces coming back. This clears the pattarai balance. '
              'Company stock is untouched — it drops when you sell the pieces.',
        PattaraiTxType.wastage =>
          'Settles the loss for this pattarai. This is the only entry that '
              'reduces company stock, so record it once a month or two.',
      };

  Future<void> _save() async {
    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid quantity in kg')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.addPattaraiStockTx(PattaraiStockTx(
        pattaraiId: _pattaraiId,
        pattaraiName: _pattarai.name,
        type: widget.type,
        // Sheet is what goes out and what the loss is measured against.
        materialType: _metal.sheet,
        quantityKg: qty,
        date: _date,
        note: _noteCtrl.text.trim(),
      ));
      if (mounted) {
        final pattaraiName = _pattarai.name;
        final type = widget.type;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        AppToast.showWith(
          messenger,
          switch (type) {
            PattaraiTxType.issue => ToastEvent.sheetSent,
            PattaraiTxType.pieces => ToastEvent.piecesBack,
            PattaraiTxType.wastage => ToastEvent.saved,
          },
          name: pattaraiName,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.type.label,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _color)),
          const SizedBox(height: 8),
          Text(_explain,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5, color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 18),

          DropdownButtonFormField<String>(
            value: _pattaraiId,
            isExpanded: true,
            items: widget.pattarais
                .map((p) => DropdownMenuItem(
                    value: p.id ?? p.name, child: Text(p.name)))
                .toList(),
            onChanged: (v) => setState(() => _pattaraiId = v!),
            decoration: const InputDecoration(labelText: 'Pattarai'),
          ),
          const SizedBox(height: 14),

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
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _metal = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _metal == m ? _kPrimary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _metal == m
                              ? _kPrimary
                              : Colors.grey.shade300),
                    ),
                    child: Text(m.chipLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _metal == m
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                  ),
                ),
              ),
              if (m != MaterialMetal.values.last) const SizedBox(width: 8),
            ]
          ]),
          const SizedBox(height: 14),

          TextField(
            controller: _qtyCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Quantity (kg)',
              helperText: widget.suggestedKg != null && widget.suggestedKg! > 0
                  ? 'Pre-filled with the pending balance — edit if different'
                  : null,
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Aug + Sep settlement'),
          ),
          const SizedBox(height: 12),

          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save ${widget.type.label.toLowerCase()}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Sell wastage â€” clears scrap out of the wastage store.
// Company sheet stock is untouched: the material already left stock when the
// wastage was recorded, so selling it only empties the scrap pile.
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _SellWastageSheet extends StatefulWidget {
  final MaterialMetal metal;
  final double inStore;
  const _SellWastageSheet({required this.metal, required this.inStore});

  @override
  State<_SellWastageSheet> createState() => _SellWastageSheetState();
}

class _SellWastageSheetState extends State<_SellWastageSheet> {
  FirebaseService get _svc => FirebaseService.instance;

  final _qtyCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _buyerCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late MaterialMetal _metal;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _metal = widget.metal;
    if (widget.inStore > 0) {
      _qtyCtrl.text = widget.inStore.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _rateCtrl.dispose();
    _buyerCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text.trim()) ?? 0;
  double get _rate => double.tryParse(_rateCtrl.text.trim()) ?? 0;

  Future<void> _save() async {
    if (_qty <= 0 || _rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter quantity and rate per kg')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _svc.addWastageSale(WastageSale(
        materialType: _metal.sheet,
        quantityKg: _qty,
        ratePerKg: _rate,
        date: _date,
        buyerName: _buyerCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      ));
      if (mounted) {
        final buyer = _buyerCtrl.text.trim();
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context, true);
        AppToast.showWith(messenger, ToastEvent.wastageSold,
            name: buyer.isEmpty ? null : buyer);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final over = _qty > widget.inStore + 0.01;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sell wastage',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _kWaste)),
          const SizedBox(height: 6),
          Text(
            'Clears scrap out of the wastage store. Sheet stock is not '
            'affected â€” that already came off when the wastage was recorded.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 11.5, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
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
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _metal = m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _metal == m ? _kWaste : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _metal == m ? _kWaste : Colors.grey.shade300),
                    ),
                    child: Text(m.chipLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _metal == m
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                  ),
                ),
              ),
              if (m != MaterialMetal.values.last) const SizedBox(width: 8),
            ]
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _qtyCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Quantity (kg)',
              helperText: widget.inStore > 0
                  ? '${widget.inStore.toStringAsFixed(2)} kg in store'
                  : null,
            ),
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    size: 15, color: Colors.orange.shade800),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'More than what is recorded in store â€” the balance will go '
                    'negative. Check the wastage entries.',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade800),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Rate (Rs per kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _buyerCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Sold to (optional)', hintText: 'Scrap buyer name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'e.g. Jan to Jun collection'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date'),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date)),
              ]),
            ),
          ),
          if (_qty > 0 && _rate > 0) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                Text('Amount',
                    style: TextStyle(
                        fontSize: 11.5, color: Colors.grey.shade700)),
                Text(
                  'Rs ${NumberFormat('#,##0.00', 'en_IN').format(_qty * _rate)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A6B2A)),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kWaste,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save wastage sale',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

