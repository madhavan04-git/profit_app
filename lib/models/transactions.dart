// lib/models/transactions.dart
// ─────────────────────────────────────────────────────────────────────────────
// BuyerTransaction  — advance / late payment / full payment from a buyer
// WorkerTransaction — salary payment given to a worker
// Both stored in Firestore under users/{uid}/buyerTransactions or workerTransactions
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// BUYER TRANSACTION
// ══════════════════════════════════════════════════════════════════════════════
enum BuyerTxType { advance, payment, latePayment, refund }

extension BuyerTxTypeExt on BuyerTxType {
  String get label {
    switch (this) {
      case BuyerTxType.advance:     return 'Advance';
      case BuyerTxType.payment:     return 'Payment';
      case BuyerTxType.latePayment: return 'Late Payment';
      case BuyerTxType.refund:      return 'Refund';
    }
  }

  String get icon {
    switch (this) {
      case BuyerTxType.advance:     return '⬆';
      case BuyerTxType.payment:     return '✓';
      case BuyerTxType.latePayment: return '⏰';
      case BuyerTxType.refund:      return '↩';
    }
  }

  // positive = money received from buyer, negative = money given back
  bool get isCredit => this != BuyerTxType.refund;

  static BuyerTxType fromString(String s) {
    switch (s) {
      case 'advance':     return BuyerTxType.advance;
      case 'latePayment': return BuyerTxType.latePayment;
      case 'refund':      return BuyerTxType.refund;
      default:            return BuyerTxType.payment;
    }
  }
}

class BuyerTransaction {
  final String? id;
  final String buyerId;
  final String buyerName;
  final BuyerTxType type;
  final double amount;
  final String note;       // optional description
  final DateTime dateTime; // exact date+time

  const BuyerTransaction({
    this.id,
    required this.buyerId,
    required this.buyerName,
    required this.type,
    required this.amount,
    this.note = '',
    required this.dateTime,
  });

  // signed amount (+ve = received, -ve = given back)
  double get signedAmount => type.isCredit ? amount : -amount;

  Map<String, dynamic> toMap() => {
    'buyerId':   buyerId,
    'buyerName': buyerName,
    'type':      type.name,
    'amount':    amount,
    'note':      note,
    'dateStr':   dateTime.toIso8601String().substring(0, 10),
    'dateTime':  dateTime.toIso8601String(),
    'timestamp': dateTime.millisecondsSinceEpoch,
  };

  factory BuyerTransaction.fromMap(String id, Map<String, dynamic> m) =>
      BuyerTransaction(
        id:       id,
        buyerId:   m['buyerId']   ?? '',
        buyerName: m['buyerName'] ?? '',
        type:      BuyerTxTypeExt.fromString(m['type'] ?? 'payment'),
        amount:    (m['amount'] as num?)?.toDouble() ?? 0,
        note:      m['note'] ?? '',
        dateTime:  m['dateTime'] != null
            ? DateTime.parse(m['dateTime'])
            : DateTime.now(),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER TRANSACTION (salary payment)
// ══════════════════════════════════════════════════════════════════════════════
enum WorkerTxType { salaryPaid, advance, bonus, deduction }

extension WorkerTxTypeExt on WorkerTxType {
  String get label {
    switch (this) {
      case WorkerTxType.salaryPaid: return 'Salary Paid';
      case WorkerTxType.advance:    return 'Advance';
      case WorkerTxType.bonus:      return 'Bonus';
      case WorkerTxType.deduction:  return 'Deduction';
    }
  }

  String get icon {
    switch (this) {
      case WorkerTxType.salaryPaid: return '💰';
      case WorkerTxType.advance:    return '⬆';
      case WorkerTxType.bonus:      return '🎁';
      case WorkerTxType.deduction:  return '⬇';
    }
  }

  // positive = paid to worker, negative = deducted
  bool get isPaid => this != WorkerTxType.deduction;

  static WorkerTxType fromString(String s) {
    switch (s) {
      case 'advance':   return WorkerTxType.advance;
      case 'bonus':     return WorkerTxType.bonus;
      case 'deduction': return WorkerTxType.deduction;
      default:          return WorkerTxType.salaryPaid;
    }
  }
}

class WorkerTransaction {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerRole;
  final WorkerTxType type;
  final double amount;
  final String note;
  final DateTime dateTime;

  const WorkerTransaction({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.workerRole,
    required this.type,
    required this.amount,
    this.note = '',
    required this.dateTime,
  });

  double get signedAmount => type.isPaid ? amount : -amount;

  Map<String, dynamic> toMap() => {
    'workerId':   workerId,
    'workerName': workerName,
    'workerRole': workerRole,
    'type':       type.name,
    'amount':     amount,
    'note':       note,
    'dateStr':    dateTime.toIso8601String().substring(0, 10),
    'dateTime':   dateTime.toIso8601String(),
    'timestamp':  dateTime.millisecondsSinceEpoch,
  };

  factory WorkerTransaction.fromMap(String id, Map<String, dynamic> m) =>
      WorkerTransaction(
        id:         id,
        workerId:   m['workerId']   ?? '',
        workerName: m['workerName'] ?? '',
        workerRole: m['workerRole'] ?? '',
        type:       WorkerTxTypeExt.fromString(m['type'] ?? 'salaryPaid'),
        amount:     (m['amount'] as num?)?.toDouble() ?? 0,
        note:       m['note'] ?? '',
        dateTime:   m['dateTime'] != null
            ? DateTime.parse(m['dateTime'])
            : DateTime.now(),
      );
}