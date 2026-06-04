// lib/screens/worker_transactions_screen.dart
// Simple Statement like PhonePe/Google Pay history for Workers

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';

class WorkerTransactionsScreen extends StatefulWidget {
  final Worker? worker;
  const WorkerTransactionsScreen({super.key, this.worker});

  @override
  State<WorkerTransactionsScreen> createState() => _WorkerTransactionsScreenState();
}

class _WorkerTransactionsScreenState extends State<WorkerTransactionsScreen> {
  final _svc = FirebaseService.instance;
  final _fmt = NumberFormat('#,##0.00', 'en_IN');
  Worker? _selectedWorker;
  Map<String, double> _workerEarnings = {};
  Map<String, List<WorkerStatementItem>> _statementCache = {};

  @override
  void initState() {
    super.initState();
    _selectedWorker = widget.worker;
    _calculateWorkerEarnings();
  }

  Future<void> _calculateWorkerEarnings() async {
    final currentMonth = DateTime.now();
    final sales = await _svc.salesForMonth(currentMonth.year, currentMonth.month);
    final workers = await _svc.getWorkers();
    
    final Map<String, double> earnings = {};
    
    for (final worker in workers) {
      double totalEarned = 0;
      for (final sale in sales) {
        final rate = sale.workerRatesPerKg[worker.role];
        if (rate != null) {
          totalEarned += rate * sale.qty;
        }
      }
      earnings[worker.id!] = totalEarned;
    }
    
    setState(() => _workerEarnings = earnings);
    
    if (_selectedWorker != null) {
      await _refreshStatement(_selectedWorker!.id!);
    }
  }

  Future<void> _refreshStatement(String workerId) async {
    final items = await _getStatementItems(workerId);
    setState(() {
      _statementCache[workerId] = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _selectedWorker == null 
            ? const Text('Worker Accounts')
            : Text('Statement - ${_selectedWorker!.name}'),
        actions: [
          if (_selectedWorker != null)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to all workers',
              onPressed: () => setState(() => _selectedWorker = null),
            ),
          if (_selectedWorker != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () => _refreshStatement(_selectedWorker!.id!),
            ),
        ],
      ),
      body: _selectedWorker == null
          ? _buildAllWorkersView()
          : _buildWorkerStatementView(_selectedWorker!),
      floatingActionButton: _selectedWorker != null
          ? FloatingActionButton.extended(
              onPressed: () => _openPaymentForm(_selectedWorker!),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Add Payment'),
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildAllWorkersView() {
    return StreamBuilder<List<Worker>>(
      stream: _svc.workersStream(),
      builder: (ctx, workersSnap) {
        if (workersSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final workers = workersSnap.data ?? [];
        
        if (workers.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.engineering_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No workers yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('Add workers from the Workers tab',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ]),
          );
        }

        return StreamBuilder<List<WorkerSimpleTransaction>>(
          stream: _svc.allWorkerSimpleTransactionsStream(),
          builder: (ctx, txsSnap) {
            final allTransactions = txsSnap.data ?? [];
            
            final Map<String, Map<String, double>> workerBalances = {};
            
            for (final worker in workers) {
              final workerTxs = allTransactions.where((tx) => tx.workerId == worker.id).toList();
              
              double totalDebit = 0;
              
              for (final tx in workerTxs) {
                if (tx.type == WorkerSimpleTxType.debit) {
                  totalDebit += tx.amount;
                }
              }
              
              final totalCredit = _workerEarnings[worker.id!] ?? 0;
              final pending = totalCredit - totalDebit;
              
              workerBalances[worker.id!] = {
                'credit': totalCredit,
                'debit': totalDebit,
                'pending': pending,
              };
            }
            
            final sortedWorkers = List<Worker>.from(workers);
            sortedWorkers.sort((a, b) => 
                (workerBalances[b.id!]?['pending'] ?? 0).compareTo(workerBalances[a.id!]?['pending'] ?? 0));
            
            return RefreshIndicator(
              onRefresh: _calculateWorkerEarnings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: sortedWorkers.length,
                itemBuilder: (_, i) => _WorkerAccountCard(
                  worker: sortedWorkers[i],
                  totalCredit: workerBalances[sortedWorkers[i].id!]!['credit']!,
                  totalDebit: workerBalances[sortedWorkers[i].id!]!['debit']!,
                  pending: workerBalances[sortedWorkers[i].id!]!['pending']!,
                  fmt: _fmt,
                  onTap: () => setState(() => _selectedWorker = sortedWorkers[i]),
                  onAddPayment: () => _openPaymentForm(sortedWorkers[i]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── SIMPLE WORKER STATEMENT VIEW like PhonePe ─────────────────────────────
  Widget _buildWorkerStatementView(Worker worker) {
    final cachedItems = _statementCache[worker.id!];
    
    if (cachedItems == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final statementItems = cachedItems;
    
    double totalCredit = 0;
    double totalDebit = 0;
    
    for (final item in statementItems) {
      if (item.type == 'credit') {
        totalCredit += item.amount;
      } else {
        totalDebit += item.amount;
      }
    }
    
    final pending = totalCredit - totalDebit;
    
    // Group by date
    final Map<String, List<WorkerStatementItem>> groupedByDate = {};
    for (final item in statementItems) {
      final dateKey = DateFormat('dd/MM/yyyy').format(item.date);
      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(item);
    }
    
    final sortedDates = groupedByDate.keys.toList()
      ..sort((a, b) {
        try {
          final dateA = DateFormat('dd/MM/yyyy').parseStrict(a);
          final dateB = DateFormat('dd/MM/yyyy').parseStrict(b);
          return dateB.compareTo(dateA);
        } catch (e) {
          return b.compareTo(a);
        }
      });
    
    return Column(children: [
      // Balance Card
      _WorkerBalanceCard(
        totalCredit: totalCredit,
        totalDebit: totalDebit,
        pending: pending,
        fmt: _fmt,
      ),
      
      Expanded(
        child: statementItems.isEmpty
            ? _emptyStatement()
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sortedDates.length,
                itemBuilder: (_, i) {
                  final date = sortedDates[i];
                  final items = groupedByDate[date]!;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...items.map((item) => _WorkerStatementItemRow(
                          item: item,
                          fmt: _fmt,
                        )),
                      ],
                    ),
                  );
                },
              ),
      ),
    ]);
  }

  Future<List<WorkerStatementItem>> _getStatementItems(String workerId) async {
    final List<WorkerStatementItem> items = [];
    
    // Get earnings from sales (Credit)
    final allSales = await _svc.getAllSales();
    final workers = await _svc.getWorkers();
    final worker = workers.firstWhere((w) => w.id == workerId, orElse: () => throw Exception('Worker not found'));
    
    for (final sale in allSales) {
      final rate = sale.workerRatesPerKg[worker.role];
      if (rate != null) {
        final earnedAmount = rate * sale.qty;
        if (earnedAmount > 0) {
          items.add(WorkerStatementItem(
            id: 'sale_${sale.id}',
            date: sale.date,
            type: 'credit',
            amount: earnedAmount,
            description: 'Earned: ${sale.productName} (${sale.qty} kg @ Rs ${_fmt.format(rate)}/kg)',
          ));
        }
      }
    }
    
    // Get all payments (Debit)
    final payments = await _svc.getWorkerSimpleTransactions(workerId);
    for (final payment in payments) {
      items.add(WorkerStatementItem(
        id: payment.id ?? '',
        date: payment.dateTime,
        type: 'debit',
        amount: payment.amount,
        description: payment.note.isNotEmpty ? payment.note : 'Payment Made',
      ));
    }
    
    // Sort by date (oldest first for running balance)
    items.sort((a, b) => a.date.compareTo(b.date));
    
    // Calculate running balance
    double runningBalance = 0;
    for (int i = 0; i < items.length; i++) {
      if (items[i].type == 'credit') {
        runningBalance += items[i].amount;
      } else {
        runningBalance -= items[i].amount;
      }
      items[i].balance = runningBalance;
    }
    
    // Sort by date (newest first for display)
    items.sort((a, b) => b.date.compareTo(a.date));
    
    return items;
  }

  Widget _emptyStatement() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No transactions yet',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade400,
              fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Earnings from sales appear automatically',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
    ]),
  );

  Future<void> _openPaymentForm(Worker worker) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkerPaymentForm(
        worker: worker, 
        onSaved: () async {
          await _calculateWorkerEarnings();
          if (_selectedWorker != null) {
            await _refreshStatement(_selectedWorker!.id!);
          }
          setState(() {});
        },
      ),
    );
  }
}

// ── Worker Statement Item Model ──────────────────────────────────────────
class WorkerStatementItem {
  final String id;
  final DateTime date;
  final String type;
  final double amount;
  final String description;
  double balance;

  WorkerStatementItem({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.balance = 0,
  });
}

// ── Worker Account Card ─────────────────────────────────────────────────
class _WorkerAccountCard extends StatelessWidget {
  final Worker worker;
  final double totalCredit;
  final double totalDebit;
  final double pending;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onAddPayment;

  const _WorkerAccountCard({
    required this.worker,
    required this.totalCredit,
    required this.totalDebit,
    required this.pending,
    required this.fmt,
    required this.onTap,
    required this.onAddPayment,
  });

  @override
  Widget build(BuildContext context) {
    final isDue = pending > 0;
    final statusColor = isDue ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(worker.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(worker.role,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
              ],
            )),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(children: [
                Text(isDue ? 'Due' : 'Settled',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                Text('Rs ${fmt.format(pending.abs())}',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
              ]),
            ),
          ]),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Expanded(child: Column(children: [
                const Text('Earned',
                    style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                Text('Rs ${fmt.format(totalCredit)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1F4E79))),
              ])),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              Expanded(child: Column(children: [
                const Text('Paid',
                    style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                Text('Rs ${fmt.format(totalDebit)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1A6B2A))),
              ])),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              Expanded(child: Column(children: [
                const Text('Balance',
                    style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                Text(isDue ? 'To Pay' : 'Settled',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: statusColor)),
              ])),
            ]),
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onAddPayment,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Add Payment'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFF1F4E79)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('View Statement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1F4E79),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ── Worker Balance Card ──────────────────────────────────────────────────────
class _WorkerBalanceCard extends StatelessWidget {
  final double totalCredit;
  final double totalDebit;
  final double pending;
  final NumberFormat fmt;

  const _WorkerBalanceCard({
    required this.totalCredit,
    required this.totalDebit,
    required this.pending,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isDue = pending > 0;
    final color = isDue ? const Color(0xFFCC4444) : const Color(0xFF1A6B2A);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1F4E79), const Color(0xFF2E6FA8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        const Text(
          'Current Balance',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rs ${fmt.format(pending.abs())}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isDue ? 'Amount to be paid' : 'Settled',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(children: [
                const Text('Total Earned', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Rs ${fmt.format(totalCredit)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
            Container(width: 1, height: 30, color: Colors.white24),
            Expanded(
              child: Column(children: [
                const Text('Total Paid', style: TextStyle(color: Colors.white70, fontSize: 11)),
                Text('Rs ${fmt.format(totalDebit)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Worker Statement Item Row (Like PhonePe History) ─────────────────────────────
class _WorkerStatementItemRow extends StatelessWidget {
  final WorkerStatementItem item;
  final NumberFormat fmt;

  const _WorkerStatementItemRow({
    required this.item,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = item.type == 'credit';
    final amountColor = isCredit ? const Color(0xFF1A6B2A) : const Color(0xFFCC4444);
    final amountPrefix = isCredit ? '+' : '-';
    final title = isCredit ? 'Credit - Earned' : 'Debit - Payment';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888888),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$amountPrefix Rs ${fmt.format(item.amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Bal: Rs ${fmt.format(item.balance)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Worker Payment Form ────────────────────────────────────────────────────
class _WorkerPaymentForm extends StatefulWidget {
  final Worker worker;
  final VoidCallback onSaved;
  
  const _WorkerPaymentForm({required this.worker, required this.onSaved});

  @override
  State<_WorkerPaymentForm> createState() => _WorkerPaymentFormState();
}

class _WorkerPaymentFormState extends State<_WorkerPaymentForm> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    final amountStr = _amountCtrl.text.trim();
    if (amountStr.isEmpty) return;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final tx = WorkerSimpleTransaction(
      workerId: widget.worker.id!,
      workerName: widget.worker.name,
      workerRole: widget.worker.role,
      type: WorkerSimpleTxType.debit,
      amount: amount,
      note: _noteCtrl.text.trim(),
      dateTime: dt,
    );
    await FirebaseService.instance.addWorkerSimpleTransaction(tx);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        Text('Add Payment — ${widget.worker.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(widget.worker.role,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
        const SizedBox(height: 20),

        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Amount (Rs) *',
            prefixText: 'Rs ',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Text(DateFormat('dd MMM yyyy').format(_date),
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.access_time_outlined,
                    size: 16, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Text(_time.format(context),
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
          )),
        ]),
        const SizedBox(height: 10),

        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. salary payment',
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B2A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ))
                : const Text('Save Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}