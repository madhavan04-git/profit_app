// lib/screens/buyers_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class BuyersScreen extends StatefulWidget {
  const BuyersScreen({super.key});
  @override State<BuyersScreen> createState() => _BuyersScreenState();
}

class _BuyersScreenState extends State<BuyersScreen> {
  final _svc = FirebaseService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buyers')),
      body: StreamBuilder<List<Buyer>>(
        stream: _svc.buyersStream(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final buyers = snap.data ?? [];
          if (buyers.isEmpty)
            return _EmptyBuyers(onAdd: () => _openForm(null));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: buyers.length,
            itemBuilder: (_, i) => _BuyerCard(
              buyer: buyers[i],
              onEdit: () => _openForm(buyers[i]),
              onHistory: () => _viewHistory(buyers[i]),
              onDelete: () => _confirmDelete(buyers[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Buyer'),
        backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _openForm(Buyer? buyer) async {
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuyerForm(buyer: buyer),
    );
  }

  Future<void> _viewHistory(Buyer buyer) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => BuyerHistoryScreen(buyer: buyer)));
  }

  Future<void> _confirmDelete(Buyer b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${b.name}?'),
        content: const Text('Buyer will be hidden. Sales history is kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) await _svc.deleteBuyer(b.id!);
  }
}

class _EmptyBuyers extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBuyers({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.people_outline, size: 72, color: Colors.grey.shade300),
    const SizedBox(height: 12),
    Text('No buyers yet', style: TextStyle(fontSize: 18, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    Text('Add buyers to track sales per customer', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
    const SizedBox(height: 24),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add Buyer'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
  ]));
}

class _BuyerCard extends StatelessWidget {
  final Buyer buyer;
  final VoidCallback onEdit, onHistory, onDelete;
  const _BuyerCard({required this.buyer, required this.onEdit,
      required this.onHistory, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 44, height: 44,
            decoration: const BoxDecoration(color: Color(0xFFE6F1FB), shape: BoxShape.circle),
            child: Center(child: Text(buyer.name.substring(0,1).toUpperCase(),
                style: const TextStyle(color: Color(0xFF1F4E79), fontWeight: FontWeight.bold, fontSize: 18)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(buyer.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (buyer.phone.isNotEmpty)
            Text(buyer.phone, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          if (buyer.address.isNotEmpty)
            Text(buyer.address, style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        Column(children: [
          _actionBtn(Icons.history, 'History', onHistory, const Color(0xFF1F4E79)),
          const SizedBox(height: 4),
          _actionBtn(Icons.edit_outlined, 'Edit', onEdit, const Color(0xFF555555)),
        ]),
        const SizedBox(width: 4),
        IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFCC4444)),
            onPressed: onDelete, padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
      ]),
    ),
  );

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap, Color color) =>
      GestureDetector(onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ]),
        ),
      );
}

// ── Buyer form ────────────────────────────────────────────────────────────────
class _BuyerForm extends StatefulWidget {
  final Buyer? buyer;
  const _BuyerForm({this.buyer});
  @override State<_BuyerForm> createState() => _BuyerFormState();
}
class _BuyerFormState extends State<_BuyerForm> {
  late final TextEditingController _name, _phone, _address;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name    = TextEditingController(text: widget.buyer?.name ?? '');
    _phone   = TextEditingController(text: widget.buyer?.phone ?? '');
    _address = TextEditingController(text: widget.buyer?.address ?? '');
  }

  @override
  void dispose() { for (final c in [_name,_phone,_address]) c.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.isEmpty) return;
    setState(() => _saving = true);
    final buyer = Buyer(id: widget.buyer?.id, name: _name.text.trim(),
        phone: _phone.text.trim(), address: _address.text.trim());
    await FirebaseService.instance.saveBuyer(buyer);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.buyer == null ? 'Add Buyer' : 'Edit Buyer',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _tf(_name, 'Buyer name *', required: true),
        const SizedBox(height: 10),
        _tf(_phone, 'Phone number', type: TextInputType.phone),
        const SizedBox(height: 10),
        _tf(_address, 'Address'),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.buyer == null ? 'Add Buyer' : 'Save Changes',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {bool required = false, TextInputType type = TextInputType.text}) =>
      TextField(controller: c, keyboardType: type,
          decoration: InputDecoration(labelText: label, filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)));
}

// ── Buyer history ─────────────────────────────────────────────────────────────
class BuyerHistoryScreen extends StatefulWidget {
  final Buyer buyer;
  const BuyerHistoryScreen({super.key, required this.buyer});
  @override State<BuyerHistoryScreen> createState() => _BuyerHistoryScreenState();
}
class _BuyerHistoryScreenState extends State<BuyerHistoryScreen> {
  List<Sale> _sales = [];
  bool _loading = true;
  double _totalKg = 0, _totalProfit = 0, _totalRevenue = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final sales = await FirebaseService.instance.salesForBuyer(widget.buyer.id!);
    double kg = 0, profit = 0, revenue = 0;
    for (final s in sales) {
      kg      += s.qty;
      profit  += s.profit;
      revenue += s.qty * s.salePrice;
    }
    setState(() {
      _sales = sales; _totalKg = kg;
      _totalProfit = profit; _totalRevenue = revenue; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    return Scaffold(
      appBar: AppBar(title: Text(widget.buyer.name)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Summary cards
              Row(children: [
                Expanded(child: _card('Total kg', '${_totalKg.toStringAsFixed(1)} kg',
                    const Color(0xFF1F4E79), const Color(0xFFE6F1FB))),
                const SizedBox(width: 10),
                Expanded(child: _card('Revenue', 'Rs ${fmt.format(_totalRevenue)}',
                    const Color(0xFF7B4F06), const Color(0xFFFAEEDA))),
                const SizedBox(width: 10),
                Expanded(child: _card('Profit', 'Rs ${fmt.format(_totalProfit)}',
                    const Color(0xFF1A6B2A), const Color(0xFFC6EFCE))),
              ]),
              const SizedBox(height: 20),
              const Text('Sale History',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              if (_sales.isEmpty)
                const Text('No sales recorded for this buyer.',
                    style: TextStyle(color: Color(0xFF888888)))
              else
                ...(_sales.map((s) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    title: Text(s.productName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${DateFormat('dd MMM yyyy').format(s.date)}  •  '
                      '${s.qty.toStringAsFixed(1)} ${s.productCategory == 'SS' ? 'kg' : 'kg'}  •  '
                      'Rs ${fmt.format(s.salePrice)}/kg',
                      style: const TextStyle(fontSize: 12)),
                    trailing: Text('Rs ${fmt.format(s.profit)}',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B2A))),
                  ),
                ))),
            ]),
    );
  }

  Widget _card(String label, String value, Color color, Color bg) =>
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ]));
}