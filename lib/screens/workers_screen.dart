// lib/screens/workers_screen.dart
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
          if (workers.isEmpty) return const Center(child: Text('No workers yet. Add workers below.'));
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(width: 42, height: 42,
            decoration: const BoxDecoration(color: Color(0xFFEAF3DE), shape: BoxShape.circle),
            child: Center(child: Text(worker.name.substring(0,1).toUpperCase(),
                style: const TextStyle(color: Color(0xFF27500A), fontWeight: FontWeight.bold)))),
        title: Text(worker.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(worker.role, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
  late final TextEditingController _name, _role, _wage;
  bool _saving = false;
  final _roles = ['Labour', 'Plasma', 'Welding', 'Runner', 'Varai', 'Polish', 'Other'];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.worker?.name ?? '');
    _role = TextEditingController(text: widget.worker?.role ?? '');
    _wage = TextEditingController(text: widget.worker?.dailyWage.toString() ?? '');
  }
  @override
  void dispose() { for (final c in [_name,_role,_wage]) c.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_name.text.isEmpty) return;
    setState(() => _saving = true);
    final w = Worker(id: widget.worker?.id, name: _name.text.trim(),
        role: _role.text.trim(), dailyWage: double.tryParse(_wage.text) ?? 0);
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.worker == null ? 'Add Worker' : 'Edit Worker',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _tf(_name, 'Worker name *'),
        const SizedBox(height: 10),
        // Role dropdown
        DropdownButtonFormField<String>(
          value: _roles.contains(_role.text) ? _role.text : null,
          hint: const Text('Select role'),
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)),
          items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => _role.text = v ?? '',
        ),
        const SizedBox(height: 10),
        _tf(_wage, 'Daily wage (Rs)', type: TextInputType.number),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, height: 50,
          child: ElevatedButton(onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4E79),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(widget.worker == null ? 'Add Worker' : 'Save',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
      ]),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {TextInputType type = TextInputType.text}) =>
      TextField(controller: c, keyboardType: type,
          decoration: InputDecoration(labelText: label, filled: true,
              fillColor: const Color(0xFFF5F6FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none)));
}

// ── Attendance tab ────────────────────────────────────────────────────────────
class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();
  @override State<_AttendanceTab> createState() => _AttendanceTabState();
}
class _AttendanceTabState extends State<_AttendanceTab> {
  final _svc = FirebaseService.instance;
  DateTime _date = DateTime.now();
  List<Worker> _workers = [];
  Map<String, bool> _present = {};
  bool _loading = true;
  bool _saving = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final workers = await _svc.getWorkers();
    final att = await _svc.attendanceForDate(_date);
    final Map<String, bool> present = { for (final w in workers) w.id!: false };
    for (final a in att) { present[a.workerId] = a.present; }
    setState(() { _workers = workers; _present = present; _loading = false; });
  }

  Future<void> _saveAttendance() async {
    setState(() => _saving = true);
    for (final w in _workers) {
      final isPresent = _present[w.id] ?? false;
      final a = WorkerAttendance(
        workerId: w.id!, workerName: w.name, workerRole: w.role,
        date: _date, present: isPresent, wage: isPresent ? w.dailyWage : 0);
      await _svc.saveAttendance(a);
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
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFFE6F1FB),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1F4E79)),
                        const SizedBox(width: 6),
                        Text(DateFormat('dd MMM yyyy').format(_date),
                            style: const TextStyle(color: Color(0xFF1F4E79), fontWeight: FontWeight.w600)),
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
              // Workers list
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
                              title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${w.role}  •  Rs ${fmt.format(w.dailyWage)}/day',
                                  style: const TextStyle(fontSize: 12)),
                              secondary: Container(width: 36, height: 36,
                                  decoration: BoxDecoration(
                                      color: isPresent ? const Color(0xFFEAF3DE) : const Color(0xFFF5F5F5),
                                      shape: BoxShape.circle),
                                  child: Icon(isPresent ? Icons.check : Icons.close,
                                      size: 18, color: isPresent ? const Color(0xFF1A6B2A)
                                          : Colors.grey)),
                              activeColor: const Color(0xFF1A6B2A),
                            ),
                          );
                        },
                      ),
              ),
              // Total & save
              Container(color: Colors.white, padding: const EdgeInsets.all(16), child: Column(children: [
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
  List<WorkerAttendance> _att = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final att = await FirebaseService.instance
        .attendanceForMonth(widget.month.year, widget.month.month);
    setState(() { _att = att.where((a) => a.present).toList(); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en_IN');
    // Group by worker
    final Map<String, Map<String, dynamic>> byWorker = {};
    for (final a in _att) {
      byWorker.putIfAbsent(a.workerName, () => {'role': a.workerRole, 'days': 0, 'total': 0.0});
      byWorker[a.workerName]!['days'] = (byWorker[a.workerName]!['days'] as int) + 1;
      byWorker[a.workerName]!['total'] = (byWorker[a.workerName]!['total'] as double) + a.wage;
    }
    final total = byWorker.values.fold(0.0, (s, v) => s + (v['total'] as double));

    return Scaffold(
      appBar: AppBar(title: Text('Wages — ${DateFormat('MMMM yyyy').format(widget.month)}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFC6EFCE),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Text('Total wages this month:',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('Rs ${fmt.format(total)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Color(0xFF1A6B2A))),
                ])),
              ...byWorker.entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${e.value['role']}  •  ${e.value['days']} days present'),
                  trailing: Text('Rs ${fmt.format(e.value['total'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          color: Color(0xFF1A6B2A), fontSize: 15)),
                ),
              )),
            ]),
    );
  }
}