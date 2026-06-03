// lib/screens/expenses_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _svc = FirebaseService.instance;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Expense> _expenses = [];
  bool _loading = true;
  double _total = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final expenses = await _svc.expensesForMonth(_month.year, _month.month);
    setState(() {
      _expenses = expenses;
      _total = expenses.fold(0, (s, x) => s + x.amount);
      _loading = false;
    });
  }

  void _prevMonth() {
    setState(() => _month = DateTime(_month.year, _month.month - 1));
    _load();
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_month.year == now.year && _month.month == now.month) return;
    setState(() => _month = DateTime(_month.year, _month.month + 1));
    _load();
  }

  Future<void> _addExpense() async {
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExpenseForm(date: _month, onSaved: _load),
    );
  }

  Future<void> _deleteExpense(Expense e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('${e.category} — ${e.description} — Rs ${e.amount.toStringAsFixed(2)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteExpense(e.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final fmtInt = NumberFormat('#,##0', 'en_IN');
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;

    // Group by category for summary
    final Map<String, double> byCategory = {};
    for (final e in _expenses) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Month selector
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  IconButton(onPressed: _prevMonth,
                      icon: const Icon(Icons.chevron_left, color: Color(0xFF1F4E79))),
                  Expanded(child: Text(DateFormat('MMMM yyyy').format(_month),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF1F4E79)))),
                  IconButton(
                      onPressed: isCurrent ? null : _nextMonth,
                      icon: Icon(Icons.chevron_right,
                          color: isCurrent ? Colors.grey.shade300 : const Color(0xFF1F4E79))),
                ]),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Total card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCCCC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.trending_down, color: Color(0xFFBB3333), size: 28),
                        const SizedBox(width: 12),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Total expenses this month',
                              style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
                          Text('Rs ${fmtInt.format(_total)}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                                  color: Color(0xFFBB3333))),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Category breakdown
                    if (byCategory.isNotEmpty) ...[
                      const Text('By category',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(children: byCategory.entries
                            .toList()
                            .map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            _catIcon(e.key),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.key,
                                style: const TextStyle(fontSize: 13))),
                            Text('Rs ${fmt.format(e.value)}',
                                style: const TextStyle(fontWeight: FontWeight.bold,
                                    color: Color(0xFFBB3333))),
                          ]),
                        )).toList()),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // All expenses list
                    const Text('All expenses',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (_expenses.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('No expenses this month.',
                            style: TextStyle(color: Color(0xFF888888)))),
                      )
                    else
                      ...(_expenses.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          leading: _catIcon(e.category),
                          title: Text(e.description.isNotEmpty ? e.description : e.category,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            '${e.category}  •  ${DateFormat('dd MMM').format(e.date)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Rs ${fmt.format(e.amount)}',
                                style: const TextStyle(fontWeight: FontWeight.bold,
                                    color: Color(0xFFBB3333), fontSize: 14)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18,
                                  color: Color(0xFFCC4444)),
                              onPressed: () => _deleteExpense(e),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ]),
                        ),
                      ))),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        backgroundColor: const Color(0xFFBB3333),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _catIcon(String cat) {
    final icons = {
      'Material': Icons.construction,
      'Runner':   Icons.run_circle_outlined,
      'Varai':    Icons.build_outlined,
      'Plasma':   Icons.electric_bolt_outlined,
      'Welding':  Icons.whatshot_outlined,
      'Labour':   Icons.people_outline,
      'Polish':   Icons.auto_fix_high_outlined,
      'Other':    Icons.category_outlined,
    };
    final colors = {
      'Material': const Color(0xFF1F4E79),
      'Runner':   const Color(0xFF7B4F06),
      'Varai':    const Color(0xFF1A6B2A),
      'Plasma':   const Color(0xFF6A1B9A),
      'Welding':  const Color(0xFFBF360C),
      'Labour':   const Color(0xFF00695C),
      'Polish':   const Color(0xFF37474F),
      'Other':    const Color(0xFF888888),
    };
    final icon  = icons[cat]  ?? Icons.category_outlined;
    final color = colors[cat] ?? const Color(0xFF888888);
    return Container(width: 36, height: 36,
        decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: color));
  }
}

// ── Expense form ──────────────────────────────────────────────────────────────
class _ExpenseForm extends StatefulWidget {
  final DateTime date;
  final VoidCallback onSaved;
  const _ExpenseForm({required this.date, required this.onSaved});
  @override State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  String _category = 'Material';
  final _desc   = TextEditingController();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  final _categories = [
    'Material', 'Runner', 'Varai', 'Plasma', 'Welding', 'Labour', 'Polish', 'Other',
  ];

  @override
  void dispose() { _desc.dispose(); _amount.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_amount.text.isEmpty) return;
    setState(() => _saving = true);
    await FirebaseService.instance.addExpense(Expense(
      category: _category,
      description: _desc.text.trim(),
      amount: double.tryParse(_amount.text) ?? 0,
      date: _date,
    ));
    widget.onSaved();
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
        const Text('Add Expense',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Category
        DropdownButtonFormField<String>(
          value: _category,
          decoration: InputDecoration(labelText: 'Category',
              filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)),
          items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _category = v!),
        ),
        const SizedBox(height: 10),

        // Description
        TextField(controller: _desc,
            decoration: InputDecoration(labelText: 'Description (optional)',
                filled: true, fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none))),
        const SizedBox(height: 10),

        // Amount
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (Rs) *',
            prefixText: 'Rs ',
            filled: true, fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),

        // Date picker
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(context: context,
                initialDate: _date, firstDate: DateTime(2024),
                lastDate: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1F4E79)),
              const SizedBox(width: 8),
              Text(DateFormat('dd MMM yyyy').format(_date),
                  style: const TextStyle(fontSize: 14)),
              const Spacer(),
              const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFF1F4E79))),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBB3333),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Expense',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
      ]),
    );
  }
}