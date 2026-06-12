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
                          onEdit: () => _editStatementItem(worker, item),
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
          // Check if product is sold by piece
          final isPieceProduct = sale.soldByPiece == true;
          
          items.add(WorkerStatementItem(
            id: 'sale_${sale.id}',
            date: sale.date,
            type: 'credit',
            amount: earnedAmount,
            description: isPieceProduct
                ? '${sale.productName} - ${sale.qty} pcs @ ₹${_fmt.format(rate)}/pc'
                : '${sale.productName} - ${sale.qty} kg @ ₹${_fmt.format(rate)}/kg',
            originalData: {
              'saleId': sale.id, 
              'qty': sale.qty, 
              'rate': rate, 
              'productName': sale.productName,
              'soldByPiece': sale.soldByPiece ?? false,
              'unit': sale.unit ?? 'kg',
            },
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
        originalData: {'paymentId': payment.id, 'note': payment.note},
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

  Future<void> _editStatementItem(Worker worker, WorkerStatementItem item) async {
    if (item.type == 'credit') {
      // Direct amount edit for earnings
      await _showEditAmountDialog(worker, item);
    } else {
      // Edit payment
      await _showEditPaymentDialog(worker, item);
    }
    
    // Refresh the statement
    await _refreshStatement(worker.id!);
    await _calculateWorkerEarnings();
    setState(() {});
  }

  // NEW: Simple amount edit dialog - just enter the amount directly
  Future<void> _showEditAmountDialog(Worker worker, WorkerStatementItem item) async {
    final saleId = item.originalData?['saleId'];
    final currentAmount = item.amount;
    final qty = item.originalData?['qty'] ?? 0.0;
    final rate = item.originalData?['rate'] ?? 0.0;
    final isPieceProduct = item.originalData?['soldByPiece'] ?? false;
    final unit = isPieceProduct ? 'pcs' : 'kg';
    
    final amountController = TextEditingController(text: currentAmount.toString());
    
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          double newAmount = double.tryParse(amountController.text) ?? 0;
          
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: Color(0xFF1F4E79)),
                const SizedBox(width: 8),
                Text('Adjust Earnings - ${worker.name}'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Product: ${item.originalData?['productName']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Worker: ${worker.role}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Quantity: ${qty.toStringAsFixed(2)} $unit'),
                            Text('Rate: ₹${_fmt.format(rate)}/$unit'),
                          ],
                        ),
                        Text(
                          'Original Amount: ₹${_fmt.format(currentAmount)}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Enter the final amount to give to worker:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      hintText: 'Enter final amount',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.currency_rupee),
                      suffixText: '₹',
                    ),
                    onChanged: (value) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'New Amount:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '₹ ${_fmt.format(newAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final newAmount = double.tryParse(amountController.text);
                  
                  if (newAmount != null && newAmount > 0 && saleId != null) {
                    // Calculate new rate based on new amount
                    // newAmount = newRate * qty => newRate = newAmount / qty
                    final newRate = newAmount / qty;
                    
                    // Update the sale in Firebase with new rate
                    await _svc.updateSaleEarnings(saleId, worker.role, qty, newRate);
                    
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Earnings adjusted from ₹${_fmt.format(currentAmount)} to ₹${_fmt.format(newAmount)}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid amount')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F4E79),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditPaymentDialog(Worker worker, WorkerStatementItem item) async {
    final paymentId = item.originalData?['paymentId'];
    final currentAmount = item.amount;
    final currentNote = item.originalData?['note'] ?? '';
    
    final amountController = TextEditingController(text: currentAmount.toString());
    final noteController = TextEditingController(text: currentNote);
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.payment, color: Color(0xFF1F4E79)),
            const SizedBox(width: 8),
            Text('Edit Payment - ${worker.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton.icon(
            onPressed: () async {
              if (paymentId != null) {
                await _svc.deleteWorkerSimpleTransaction(paymentId);
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment deleted')),
                );
              }
            },
            icon: const Icon(Icons.delete, color: Colors.red),
            label: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final newAmount = double.tryParse(amountController.text);
              final newNote = noteController.text;
              
              if (newAmount != null && newAmount > 0 && paymentId != null) {
                await _svc.updateWorkerSimpleTransaction(
                  paymentId,
                  amount: newAmount,
                  note: newNote,
                );
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment updated successfully')),
                );
              }
            },
            icon: const Icon(Icons.update),
            label: const Text('Update'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F4E79),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
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
  double amount;
  final String description;
  double balance;
  final Map<String, dynamic>? originalData;

  WorkerStatementItem({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    this.balance = 0,
    this.originalData,
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
  final VoidCallback onEdit;

  const _WorkerStatementItemRow({
    required this.item,
    required this.fmt,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = item.type == 'credit';
    final amountColor = isCredit ? const Color(0xFF1A6B2A) : const Color(0xFFCC4444);
    final amountPrefix = isCredit ? '+' : '-';
    final title = isCredit ? '💰 Earnings' : '💳 Payment';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F4E79).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, size: 12, color: Color(0xFF1F4E79)),
                              SizedBox(width: 2),
                              Text('Adjust', style: TextStyle(fontSize: 10, color: Color(0xFF1F4E79))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF888888),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$amountPrefix ₹ ${fmt.format(item.amount)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ₹ ${fmt.format(item.balance)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF888888),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
            labelText: 'Amount (₹) *',
            prefixText: '₹ ',
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