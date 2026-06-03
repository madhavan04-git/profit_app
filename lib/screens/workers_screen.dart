// lib/screens/workers_screen.dart
// My Pattarii — Workers screen
// Worker roles match product cost fields exactly:
//   Labour 1, Labour 2, Labour 3, Labour 4,
//   Runner 1, Runner 2, Polish 1, Polish 2,
//   Vettu 1, Vettu 2, Welding 1, Welding 2,
//   Spinner 1, Spinner 2, Plasma, Varai

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});
  @override State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Workers'),
      bottom: TabBar(controller: _tabs, tabs: const [
        Tab(text: 'Workers list'), Tab(text: 'Attendance'),
      ]),
    ),
    body: TabBarView(controller: _tabs, children: const [
      _WorkersList(), _AttendanceTab(),
    ]),
  );
}

// ── Workers list ──────────────────────────────────────────────────────────────
class _WorkersList extends StatelessWidget {
  const _WorkersList();
  @override
  Widget build(BuildContext context) {
    final svc = FirebaseService.instance;
    return Scaffold(
      body: StreamBuilder<List<Worker>>(
        stream: svc.workersStream(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final workers = snap.data!;
          if (workers.isEmpty) return const Center(
              child: Padding(padding: EdgeInsets.all(24),
                child: Text('No workers yet.\nAdd workers using the button below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF888888)))));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: workers.length,
            itemBuilder: (_, i) => _WorkerTile(worker: workers[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add Worker'),
        backgroundColor: const Color(0xFF1F4E79), foregroundColor: Colors.white,
      ),
    );
  }

  void _openForm(BuildContext context, Worker? w) {
    showModalBottomSheet(context: context, isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _WorkerForm(worker: w));
  }
}

class _WorkerTile extends StatelessWidget {
  final Worker worker;
  const _WorkerTile({required this.worker});
  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEEEEEE))),
      child: ListTile(
        leading: Container(width: 42, height: 42,
            decoration: const BoxDecoration(color: Color(0xFFEAF3DE), shape: BoxShape.circle),
            child: Center(child: Text(worker.name.substring(0,1).toUpperCase(),
                style: const TextStyle(color: Color(0xFF27500A), fontWeight: FontWeight.bold)))),
        title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFE6F1FB),
                borderRadius: BorderRadius.circular(4)),
            child: Text(worker.role,
                style: const TextStyle(fontSize: 11, color: Color(0xFF1F4E79),
                    fontWeight: FontWeight.w500)),
          ),
        ]),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Rs ${fmt.format(worker.dailyWage)}/day',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A6B2A))),
          GestureDetector(
            onTap: () => showModalBottomSheet(context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _WorkerForm(worker: worker)),
            child: const Text('edit', style: TextStyle(fontSize: 11, color: Color(0xFF1F4E79))),
          ),
        ]),
      ),
    );
  }
}

// ── Worker form ───────────────────────────────────────────────────────────────
class _WorkerForm extends StatefulWidget {
  final Worker? worker;
  const _WorkerForm({this.worker});
  @override State<_WorkerForm> createState() => _WorkerFormState();
}

class _WorkerFormState extends State<_WorkerForm> {
  late final TextEditingController _name, _wage;
  String? _role;
  bool _saving = false;

  // All valid roles — must match product cost field keys
  static const _roles = [
    'Labour 1', 'Labour 2', 'Labour 3', 'Labour 4',
    'Runner 1', 'Runner 2',
    'Polish 1', 'Polish 2',
    'Vettu 1',  'Vettu 2',
    'Welding 1','Welding 2',
    'Spinner 1','Spinner 2',
    'Plasma',
    'Varai',
  ];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.worker?.name ?? '');
    _wage = TextEditingController(text: widget.worker?.dailyWage.toString() ?? '');
    _role = widget.worker?.role;
    // Migrate old roles if needed
    if (_role != null && !_roles.contains(_role)) _role = null;
  }
  @override
  void dispose() { _name.dispose(); _wage.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.isEmpty || _role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill name and role')));
      return;
    }
    setState(() => _saving = true);
    final w = Worker(id: widget.worker?.id, name: _name.text.trim(),
        role: _role!, dailyWage: double.tryParse(_wage.text) ?? 0);
    await FirebaseService.instance.saveWorker(w);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.worker == null ? 'Add Worker' : 'Edit Worker',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Worker role must match the product cost field\n(e.g. "Labour 1" earns Labour 1 cost × qty sold)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
        const SizedBox(height: 16),
        // Name
        TextField(controller: _name,
          decoration: InputDecoration(labelText: 'Worker name *',
            filled: true, fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 10),
        // Role dropdown — all valid roles
        DropdownButtonFormField<String>(
          value: _role,
          hint: const Text('Select role *'),
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)),
          isExpanded: true,
          items: _roles.map((r) => DropdownMenuItem(value: r,
              child: Text(r, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (v) => setState(() => _role = v),
        ),
        const SizedBox(height: 10),
        // Daily wage
        TextField(controller: _wage, keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Daily wage (Rs) — for attendance only',
            filled: true, fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 6),
        // Info note
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(8)),
          child: const Text(
            '💡 Monthly salary is auto-calculated from sales:\n'
            'Worker earns = (their cost in product) × (qty sold)\n'
            'e.g. Plasma worker at Rs 5/piece × 20kg sold = Rs 100',
            style: TextStyle(fontSize: 11, color: Color(0xFF7B4F06))),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.worker == null ? 'Add Worker' : 'Save',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
      ])),
    );
  }
}

// ── Attendance Tab ────────────────────────────────────────────────────────────
class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();
  @override State<_AttendanceTab> createState() => _AttendanceTabState();
}
class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _date = DateTime.now();
  List<Worker> _workers = [];
  Map<String, bool> _present = {};
  bool _loading = true, _saving = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final workers = await FirebaseService.instance.getWorkers();
    final att     = await FirebaseService.instance.attendanceForDate(_date);
    final Map<String, bool> present = {};
    for (final w in workers) { present[w.id!] = false; }
    for (final a in att) { if (a.present) present[a.workerId] = true; }
    setState(() { _workers = workers; _present = present; _loading = false; });
  }

  Future<void> _saveAttendance() async {
    setState(() => _saving = true);
    final svc = FirebaseService.instance;
    for (final w in _workers) {
      final isPresent = _present[w.id] ?? false;
      await svc.saveAttendance(WorkerAttendance(
        workerId: w.id!, workerName: w.name, workerRole: w.role,
        date: _date, present: isPresent, wage: isPresent ? w.dailyWage : 0,
      ));
    }
    setState(() => _saving = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved'),
            backgroundColor: Color(0xFF1A6B2A)));
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context,
        initialDate: _date, firstDate: DateTime(2024), lastDate: DateTime.now());
    if (d != null) { setState(() => _date = d); _load(); }
  }

  Future<void> _viewMonthly() async {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _MonthlyWagesScreen(month: _date)));
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    final totalWage = _workers.fold(0.0, (s, w) =>
        s + ((_present[w.id] ?? false) ? w.dailyWage : 0));

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Date bar
              Container(color: Colors.white, padding: const EdgeInsets.all(14),
                child: Row(children: [
                  GestureDetector(onTap: _pickDate,
                    child: Container(padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFE6F1FB),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1F4E79)),
                        const SizedBox(width: 6),
                        Text(DateFormat('dd MMM yyyy').format(_date),
                            style: const TextStyle(color: Color(0xFF1F4E79),
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(onPressed: _viewMonthly,
                      icon: const Icon(Icons.bar_chart, size: 16),
                      label: const Text('Monthly wages')),
                ]),
              ),
              const Divider(height: 1),
              Expanded(
                child: _workers.isEmpty
                    ? const Center(child: Text('No workers. Add workers in the Workers tab.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _workers.length,
                        itemBuilder: (_, i) {
                          final w = _workers[i];
                          final isPresent = _present[w.id] ?? false;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isPresent ? const Color(0xFFF0FBF0) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isPresent
                                  ? const Color(0xFF90C890) : const Color(0xFFEEEEEE)),
                            ),
                            child: CheckboxListTile(
                              value: isPresent,
                              onChanged: (v) => setState(() => _present[w.id!] = v ?? false),
                              title: Text(w.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${w.role}  •  Rs ${fmt.format(w.dailyWage)}/day',
                                  style: const TextStyle(fontSize: 12)),
                              secondary: Container(width: 36, height: 36,
                                  decoration: BoxDecoration(
                                      color: isPresent ? const Color(0xFFEAF3DE)
                                          : const Color(0xFFF5F5F5),
                                      shape: BoxShape.circle),
                                  child: Icon(isPresent ? Icons.check : Icons.close,
                                      size: 18, color: isPresent
                                          ? const Color(0xFF1A6B2A) : Colors.grey)),
                              activeColor: const Color(0xFF1A6B2A),
                            ),
                          );
                        },
                      ),
              ),
              Container(color: Colors.white, padding: const EdgeInsets.all(16),
                  child: Column(children: [
                Row(children: [
                  const Text('Today\'s wage total:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('Rs ${fmt.format(totalWage)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A6B2A))),
                ]),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity, height: 48,
                  child: ElevatedButton(onPressed: _saving ? null : _saveAttendance,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save attendance',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
              ])),
            ]),
    );
  }
}

// ── Monthly wages ─────────────────────────────────────────────────────────────
class _MonthlyWagesScreen extends StatefulWidget {
  final DateTime month;
  const _MonthlyWagesScreen({required this.month});
  @override State<_MonthlyWagesScreen> createState() => _MonthlyWagesState();
}
class _MonthlyWagesState extends State<_MonthlyWagesScreen> {
  Map<String, Map<String, dynamic>> _byWorker = {};
  Map<String, double> _salesWages = {};
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final svc = FirebaseService.instance;
    final att  = await svc.attendanceForMonth(widget.month.year, widget.month.month);
    final summary = await svc.monthlySummary(widget.month.year, widget.month.month);

    final Map<String, Map<String, dynamic>> byWorker = {};
    for (final a in att.where((a) => a.present)) {
      byWorker.putIfAbsent(a.workerName, () => {'role': a.workerRole, 'days': 0, 'attendWage': 0.0});
      byWorker[a.workerName]!['days'] = (byWorker[a.workerName]!['days'] as int) + 1;
      byWorker[a.workerName]!['attendWage'] =
          (byWorker[a.workerName]!['attendWage'] as double) + a.wage;
    }
    setState(() {
      _byWorker  = byWorker;
      _salesWages = summary.workerWageByRole;
      _loading   = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    final totalAttend = _byWorker.values.fold(0.0, (s, v) => s + (v['attendWage'] as double));
    final totalSales  = _salesWages.values.fold(0.0, (s, v) => s + v);

    return Scaffold(
      appBar: AppBar(title: Text('Wages — ${DateFormat('MMMM yyyy').format(widget.month)}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              // Totals
              Row(children: [
                Expanded(child: _totalCard('Attendance Wages',
                    'Rs ${fmt.format(totalAttend)}', const Color(0xFF1F4E79))),
                const SizedBox(width: 10),
                Expanded(child: _totalCard('Sales Wages',
                    'Rs ${fmt.format(totalSales)}', const Color(0xFF1A6B2A))),
              ]),
              const SizedBox(height: 20),

              // Sales-based worker wages
              if (_salesWages.isNotEmpty) ...[
                const Text('Salary from Sales (Product-based)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: Color(0xFF1F4E79))),
                const SizedBox(height: 4),
                const Text(
                  'Each worker is paid based on qty of product sold × their rate per kg',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                ),
                const SizedBox(height: 10),
                ..._salesWages.entries.toList()
                    .map((e) => _SalesWageTile(
                      role: e.key, wage: e.value, fmt: fmt)),
                const SizedBox(height: 20),
              ],

              // Attendance wages
              if (_byWorker.isNotEmpty) ...[
                const Text('Attendance Wages (Daily)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                        color: Color(0xFF1F4E79))),
                const SizedBox(height: 10),
                ..._byWorker.entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e.value['role']}  •  ${e.value['days']} days present'),
                    trailing: Text('Rs ${fmt.format(e.value['attendWage'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            color: Color(0xFF1A6B2A), fontSize: 15)),
                  ),
                )),
              ],
            ]),
    );
  }

  Widget _totalCard(String label, String value, Color color) =>
      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]));
}

class _SalesWageTile extends StatelessWidget {
  final String role;
  final double wage;
  final NumberFormat fmt;
  const _SalesWageTile({required this.role, required this.wage, required this.fmt});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE))),
    child: ListTile(
      leading: Container(width: 38, height: 38,
          decoration: const BoxDecoration(
              color: Color(0xFFC6EFCE), shape: BoxShape.circle),
          child: const Icon(Icons.person, size: 18, color: Color(0xFF1A6B2A))),
      title: Text(role, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: const Text('Calculated from product sales this month',
          style: TextStyle(fontSize: 11)),
      trailing: Text('Rs ${fmt.format(wage)}',
          style: const TextStyle(fontWeight: FontWeight.bold,
              color: Color(0xFF1A6B2A), fontSize: 15)),
    ),
  );
}