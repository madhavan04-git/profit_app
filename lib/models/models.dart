// lib/models/models.dart
// My Pattarii — Full cost model

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT
// ══════════════════════════════════════════════════════════════════════════════
class Product {
  final String? id;
  final String name;
  final String category;
  final String padii;
  final int productWeightG;
  final double sellPricePerKg;
  final bool soldByPiece;
  final String unit;
  final bool isActive;

  // ── Cost fields (per productWeightG grams) ──────────────────────────────
  final double costMaterial;
  final double costPlasma1;
  final double costPlasma2;
  final double costLabour1;
  final double costLabour2;
  final double costLabour3;
  final double costLabour4;
  final double costVettu1;
  final double costVettu2;
  final double costWelding1;
  final double costWelding2;
  final double costRunner1;
  final double costRunner2;
  final double costVarai;
  final double costPolish1;
  final double costPolish2;
  final double costSpinner1;
  final double costSpinner2;

  const Product({
    this.id,
    required this.name,
    required this.category,
    this.padii = '',
    required this.productWeightG,
    required this.sellPricePerKg,
    this.soldByPiece = false,
    this.unit = 'kg',
    this.isActive = true,
    this.costMaterial = 0,
    this.costPlasma1 = 0,
    this.costPlasma2 = 0,
    this.costLabour1 = 0,
    this.costLabour2 = 0,
    this.costLabour3 = 0,
    this.costLabour4 = 0,
    this.costVettu1 = 0,
    this.costVettu2 = 0,
    this.costWelding1 = 0,
    this.costWelding2 = 0,
    this.costRunner1 = 0,
    this.costRunner2 = 0,
    this.costVarai = 0,
    this.costPolish1 = 0,
    this.costPolish2 = 0,
    this.costSpinner1 = 0,
    this.costSpinner2 = 0,
  });

  double get totalCostPerProduct =>
      costMaterial + costPlasma1 + costPlasma2 +
      costLabour1 + costLabour2 + costLabour3 + costLabour4 +
      costVettu1 + costVettu2 +
      costWelding1 + costWelding2 +
      costRunner1 + costRunner2 +
      costVarai +
      costPolish1 + costPolish2 +
      costSpinner1 + costSpinner2;

  double get costPerKg => totalCostPerProduct * (1000.0 / productWeightG);
  double get profitPerKg => sellPricePerKg - costPerKg;
  double get profitPerPiece => profitPerKg * (productWeightG / 1000.0);
  double get profitPerUnit => soldByPiece ? profitPerPiece : profitPerKg;
  double profitForQty(double qty) => qty * profitPerUnit;

  Map<String, double> get workerCostsPerProduct => {
    if (costPlasma1 > 0) 'Plasma 1': costPlasma1,
    if (costPlasma2 > 0) 'Plasma 2': costPlasma2,
    if (costLabour1 > 0) 'Labour 1': costLabour1,
    if (costLabour2 > 0) 'Labour 2': costLabour2,
    if (costLabour3 > 0) 'Labour 3': costLabour3,
    if (costLabour4 > 0) 'Labour 4': costLabour4,
    if (costVettu1 > 0) 'Vettu 1': costVettu1,
    if (costVettu2 > 0) 'Vettu 2': costVettu2,
    if (costWelding1 > 0) 'Welding 1': costWelding1,
    if (costWelding2 > 0) 'Welding 2': costWelding2,
    if (costRunner1 > 0) 'Runner 1': costRunner1,
    if (costRunner2 > 0) 'Runner 2': costRunner2,
    if (costVarai > 0) 'Varai': costVarai,
    if (costPolish1 > 0) 'Polish 1': costPolish1,
    if (costPolish2 > 0) 'Polish 2': costPolish2,
    if (costSpinner1 > 0) 'Spinner 1': costSpinner1,
    if (costSpinner2 > 0) 'Spinner 2': costSpinner2,
  };

  Map<String, double> get workerRatesPerKg {
    final Map<String, double> result = {};
    workerCostsPerProduct.forEach((role, costPerPiece) {
      result[role] = costPerPiece * (1000.0 / productWeightG);
    });
    return result;
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'padii': padii,
    'productWeightG': productWeightG,
    'sellPricePerKg': sellPricePerKg,
    'soldByPiece': soldByPiece,
    'unit': unit,
    'isActive': isActive,
    'costMaterial': costMaterial,
    'costPlasma1': costPlasma1,
    'costPlasma2': costPlasma2,
    'costLabour1': costLabour1,
    'costLabour2': costLabour2,
    'costLabour3': costLabour3,
    'costLabour4': costLabour4,
    'costVettu1': costVettu1,
    'costVettu2': costVettu2,
    'costWelding1': costWelding1,
    'costWelding2': costWelding2,
    'costRunner1': costRunner1,
    'costRunner2': costRunner2,
    'costVarai': costVarai,
    'costPolish1': costPolish1,
    'costPolish2': costPolish2,
    'costSpinner1': costSpinner1,
    'costSpinner2': costSpinner2,
  };

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
    id: id,
    name: m['name'] ?? '',
    category: m['category'] ?? '',
    padii: m['padii'] ?? '',
    productWeightG: (m['productWeightG'] as num?)?.toInt() ?? 300,
    sellPricePerKg: (m['sellPricePerKg'] as num?)?.toDouble() ?? 0,
    soldByPiece: m['soldByPiece'] ?? false,
    unit: m['unit'] ?? 'kg',
    isActive: m['isActive'] ?? true,
    costMaterial: _toDouble(m['costMaterial']),
    costPlasma1: _toDouble(m['costPlasma1'] ?? m['costPlasma']),
    costPlasma2: _toDouble(m['costPlasma2']),
    costLabour1: _toDouble(m['costLabour1']),
    costLabour2: _toDouble(m['costLabour2']),
    costLabour3: _toDouble(m['costLabour3']),
    costLabour4: _toDouble(m['costLabour4']),
    costVettu1: _toDouble(m['costVettu1']),
    costVettu2: _toDouble(m['costVettu2']),
    costWelding1: _toDouble(m['costWelding1']),
    costWelding2: _toDouble(m['costWelding2']),
    costRunner1: _toDouble(m['costRunner1']),
    costRunner2: _toDouble(m['costRunner2']),
    costVarai: _toDouble(m['costVarai']),
    costPolish1: _toDouble(m['costPolish1']),
    costPolish2: _toDouble(m['costPolish2']),
    costSpinner1: _toDouble(m['costSpinner1']),
    costSpinner2: _toDouble(m['costSpinner2']),
  );

  static double _toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
}

// ══════════════════════════════════════════════════════════════════════════════
// SALE (UPDATED with tracking fields including buyer deduction)
// ══════════════════════════════════════════════════════════════════════════════
class Sale {
  final String? id;
  final String productId;
  final String productName;
  final String productCategory;
  final String? buyerId;
  final String? buyerName;
  final double qty;
  final double salePrice;
  final double profit;
  final DateTime date;
  final Map<String, double> workerRatesPerKg;
  final bool soldByPiece;
  final String unit;

  // Tracking fields
  final String? rawMaterialCreditId;   // ID of the SimpleTransaction for buyer credit
  final String? consumptionTxId;       // ID of the RawMaterialTransaction deducting global stock
  final String? consumedMaterialType;  // e.g. 'SS Sheet'
  final double? consumedKg;            // kg of raw material consumed from global stock

  // NEW: buyer deduction tracking
  final double? buyerDeductionKg;          // kg deducted from buyer's stock
  final String? buyerDeductionMaterialType; // material type deducted from buyer

  // NEW: which Pattarai (shop/label) this sale was recorded under — purely a
  // display label, does not affect stock or profit calculations.
  final String? pattaraiName;

  const Sale({
    this.id,
    required this.productId,
    required this.productName,
    required this.productCategory,
    this.buyerId,
    this.buyerName,
    required this.qty,
    required this.salePrice,
    required this.profit,
    required this.date,
    this.workerRatesPerKg = const {},
    this.soldByPiece = false,
    this.unit = 'kg',
    this.rawMaterialCreditId,
    this.consumptionTxId,
    this.consumedMaterialType,
    this.consumedKg,
    this.buyerDeductionKg,
    this.buyerDeductionMaterialType,
    this.pattaraiName,
  });

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'productName': productName,
    'productCategory': productCategory,
    'buyerId': buyerId,
    'buyerName': buyerName,
    'qty': qty,
    'salePrice': salePrice,
    'profit': profit,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
    'workerRatesPerKg': workerRatesPerKg,
    'soldByPiece': soldByPiece,
    'unit': unit,
    if (rawMaterialCreditId != null) 'rawMaterialCreditId': rawMaterialCreditId,
    if (consumptionTxId != null) 'consumptionTxId': consumptionTxId,
    if (consumedMaterialType != null) 'consumedMaterialType': consumedMaterialType,
    if (consumedKg != null) 'consumedKg': consumedKg,
    if (buyerDeductionKg != null) 'buyerDeductionKg': buyerDeductionKg,
    if (buyerDeductionMaterialType != null) 'buyerDeductionMaterialType': buyerDeductionMaterialType,
    if (pattaraiName != null) 'pattaraiName': pattaraiName,
  };

  factory Sale.fromMap(String id, Map<String, dynamic> m) {
    final rawRates = m['workerRatesPerKg'] as Map<String, dynamic>? ?? {};
    final rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
    return Sale(
      id: id,
      productId: m['productId'] ?? '',
      productName: m['productName'] ?? '',
      productCategory: m['productCategory'] ?? '',
      buyerId: m['buyerId'],
      buyerName: m['buyerName'],
      qty: (m['qty'] as num?)?.toDouble() ?? 0,
      salePrice: (m['salePrice'] as num?)?.toDouble() ?? 0,
      profit: (m['profit'] as num?)?.toDouble() ?? 0,
      date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
      workerRatesPerKg: rates,
      soldByPiece: m['soldByPiece'] ?? false,
      unit: m['unit'] ?? 'kg',
      rawMaterialCreditId: m['rawMaterialCreditId'] as String?,
      consumptionTxId: m['consumptionTxId'] as String?,
      consumedMaterialType: m['consumedMaterialType'] as String?,
      consumedKg: (m['consumedKg'] as num?)?.toDouble(),
      buyerDeductionKg: (m['buyerDeductionKg'] as num?)?.toDouble(),
      buyerDeductionMaterialType: m['buyerDeductionMaterialType'] as String?,
      pattaraiName: m['pattaraiName'] as String?,
    );
  }

  String get displayUnit => soldByPiece ? unit : 'kg';
  String get qtyDisplay => '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)} $displayUnit';
}

// ══════════════════════════════════════════════════════════════════════════════
// BUYER
// ══════════════════════════════════════════════════════════════════════════════
class Buyer {
  final String? id;
  final String name;
  final String phone;
  final String address;
  final bool isActive;

  const Buyer({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'isActive': isActive,
  };

  factory Buyer.fromMap(String id, Map<String, dynamic> m) => Buyer(
    id: id,
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    address: m['address'] ?? '',
    isActive: m['isActive'] ?? true,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// BUYER TRANSACTION (legacy)
// ══════════════════════════════════════════════════════════════════════════════
enum BuyerTxType { advance, payment, latePayment, refund }

extension BuyerTxTypeExt on BuyerTxType {
  String get label {
    switch (this) {
      case BuyerTxType.advance: return 'Advance';
      case BuyerTxType.payment: return 'Payment';
      case BuyerTxType.latePayment: return 'Late Payment';
      case BuyerTxType.refund: return 'Refund';
    }
  }
  bool get isCredit => this != BuyerTxType.refund;
  static BuyerTxType fromString(String s) {
    switch (s) {
      case 'advance': return BuyerTxType.advance;
      case 'latePayment': return BuyerTxType.latePayment;
      case 'refund': return BuyerTxType.refund;
      default: return BuyerTxType.payment;
    }
  }
}

class BuyerTransaction {
  final String? id;
  final String buyerId;
  final String buyerName;
  final BuyerTxType type;
  final double amount;
  final String note;
  final DateTime dateTime;

  const BuyerTransaction({
    this.id,
    required this.buyerId,
    required this.buyerName,
    required this.type,
    required this.amount,
    this.note = '',
    required this.dateTime,
  });

  double get signedAmount => type.isCredit ? amount : -amount;

  Map<String, dynamic> toMap() => {
    'buyerId': buyerId,
    'buyerName': buyerName,
    'type': type.name,
    'amount': amount,
    'note': note,
    'dateStr': dateTime.toIso8601String().substring(0, 10),
    'dateTime': dateTime.toIso8601String(),
    'timestamp': dateTime.millisecondsSinceEpoch,
  };

  factory BuyerTransaction.fromMap(String id, Map<String, dynamic> m) => BuyerTransaction(
    id: id,
    buyerId: m['buyerId'] ?? '',
    buyerName: m['buyerName'] ?? '',
    type: BuyerTxTypeExt.fromString(m['type'] ?? 'payment'),
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    note: m['note'] ?? '',
    dateTime: m['dateTime'] != null ? DateTime.parse(m['dateTime']) : DateTime.now(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER
// ══════════════════════════════════════════════════════════════════════════════
class Worker {
  final String? id;
  final String name;
  final String role;
  final double dailyWage;
  final bool isActive;

  const Worker({
    this.id,
    required this.name,
    required this.role,
    required this.dailyWage,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'role': role,
    'dailyWage': dailyWage,
    'isActive': isActive,
  };

  factory Worker.fromMap(String id, Map<String, dynamic> m) => Worker(
    id: id,
    name: m['name'] ?? '',
    role: m['role'] ?? '',
    dailyWage: (m['dailyWage'] as num?)?.toDouble() ?? 0,
    isActive: m['isActive'] ?? true,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER TRANSACTION (legacy)
// ══════════════════════════════════════════════════════════════════════════════
enum WorkerTxType { salaryPaid, advance, bonus, deduction }

extension WorkerTxTypeExt on WorkerTxType {
  String get label {
    switch (this) {
      case WorkerTxType.salaryPaid: return 'Salary Paid';
      case WorkerTxType.advance: return 'Advance';
      case WorkerTxType.bonus: return 'Bonus';
      case WorkerTxType.deduction: return 'Deduction';
    }
  }
  bool get isPaid => this != WorkerTxType.deduction;
  static WorkerTxType fromString(String s) {
    switch (s) {
      case 'advance': return WorkerTxType.advance;
      case 'bonus': return WorkerTxType.bonus;
      case 'deduction': return WorkerTxType.deduction;
      default: return WorkerTxType.salaryPaid;
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

  double get signedAmount => type.isPaid ? -amount : amount;

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'workerName': workerName,
    'workerRole': workerRole,
    'type': type.name,
    'amount': amount,
    'note': note,
    'dateStr': dateTime.toIso8601String().substring(0, 10),
    'dateTime': dateTime.toIso8601String(),
    'timestamp': dateTime.millisecondsSinceEpoch,
  };

  factory WorkerTransaction.fromMap(String id, Map<String, dynamic> m) => WorkerTransaction(
    id: id,
    workerId: m['workerId'] ?? '',
    workerName: m['workerName'] ?? '',
    workerRole: m['workerRole'] ?? '',
    type: WorkerTxTypeExt.fromString(m['type'] ?? 'salaryPaid'),
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    note: m['note'] ?? '',
    dateTime: m['dateTime'] != null ? DateTime.parse(m['dateTime']) : DateTime.now(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER ATTENDANCE
// ══════════════════════════════════════════════════════════════════════════════
class WorkerAttendance {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerRole;
  final DateTime date;
  final bool present;
  final double wage;

  const WorkerAttendance({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.workerRole,
    required this.date,
    required this.present,
    required this.wage,
  });

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'workerName': workerName,
    'workerRole': workerRole,
    'date': date.toIso8601String().substring(0, 10),
    'present': present,
    'wage': wage,
  };

  factory WorkerAttendance.fromMap(String id, Map<String, dynamic> m) => WorkerAttendance(
    id: id,
    workerId: m['workerId'] ?? '',
    workerName: m['workerName'] ?? '',
    workerRole: m['workerRole'] ?? '',
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    present: m['present'] ?? false,
    wage: (m['wage'] as num?)?.toDouble() ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE
// ══════════════════════════════════════════════════════════════════════════════
class Expense {
  final String? id;
  final String category;
  final String description;
  final double amount;
  final DateTime date;

  const Expense({
    this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'category': category,
    'description': description,
    'amount': amount,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
  };

  factory Expense.fromMap(String id, Map<String, dynamic> m) => Expense(
    id: id,
    category: m['category'] ?? '',
    description: m['description'] ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SIMPLE TRANSACTIONS (Credit/Debit for Buyers)
// ══════════════════════════════════════════════════════════════════════════════
enum SimpleTxType { credit, debit }

class SimpleTransaction {
  final String? id;
  final String buyerId;
  final String buyerName;
  final SimpleTxType type;
  final double amount;
  final String note;
  final DateTime dateTime;

  const SimpleTransaction({
    this.id,
    required this.buyerId,
    required this.buyerName,
    required this.type,
    required this.amount,
    this.note = '',
    required this.dateTime,
  });

  Map<String, dynamic> toMap() => {
    'buyerId': buyerId,
    'buyerName': buyerName,
    'type': type.name,
    'amount': amount,
    'note': note,
    'dateTime': dateTime.toIso8601String(),
    'timestamp': dateTime.millisecondsSinceEpoch,
  };

  factory SimpleTransaction.fromMap(String id, Map<String, dynamic> m) {
    final typeStr = m['type'] ?? 'credit';
    return SimpleTransaction(
      id: id,
      buyerId: m['buyerId'] ?? '',
      buyerName: m['buyerName'] ?? '',
      type: typeStr == 'credit' ? SimpleTxType.credit : SimpleTxType.debit,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      note: m['note'] ?? '',
      dateTime: m['dateTime'] != null ? DateTime.parse(m['dateTime']) : DateTime.now(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER SIMPLE TRANSACTIONS (Credit/Debit for Workers)
// ══════════════════════════════════════════════════════════════════════════════
enum WorkerSimpleTxType { credit, debit }

class WorkerSimpleTransaction {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerRole;
  final WorkerSimpleTxType type;
  final double amount;
  final String note;
  final DateTime dateTime;

  const WorkerSimpleTransaction({
    this.id,
    required this.workerId,
    required this.workerName,
    required this.workerRole,
    required this.type,
    required this.amount,
    this.note = '',
    required this.dateTime,
  });

  Map<String, dynamic> toMap() => {
    'workerId': workerId,
    'workerName': workerName,
    'workerRole': workerRole,
    'type': type.name,
    'amount': amount,
    'note': note,
    'dateTime': dateTime.toIso8601String(),
    'timestamp': dateTime.millisecondsSinceEpoch,
  };

  factory WorkerSimpleTransaction.fromMap(String id, Map<String, dynamic> m) {
    final typeStr = m['type'] ?? 'credit';
    return WorkerSimpleTransaction(
      id: id,
      workerId: m['workerId'] ?? '',
      workerName: m['workerName'] ?? '',
      workerRole: m['workerRole'] ?? '',
      type: typeStr == 'credit' ? WorkerSimpleTxType.credit : WorkerSimpleTxType.debit,
      amount: (m['amount'] as num?)?.toDouble() ?? 0,
      note: m['note'] ?? '',
      dateTime: m['dateTime'] != null ? DateTime.parse(m['dateTime']) : DateTime.now(),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// RAW MATERIAL TRACKING (NEW)
// ══════════════════════════════════════════════════════════════════════════════
/// The metal itself, independent of the form it comes in. Stock totals are
/// reported per metal (SS = sheet + circle), while purchases and sales are
/// still recorded against the exact [RawMaterialType].
enum MaterialMetal {
  ss, brass, copper;

  String get displayName {
    switch (this) {
      case ss: return 'SS';
      case brass: return 'Brass';
      case copper: return 'Copper';
    }
  }

  /// Label for the selector chips.
  String get chipLabel => displayName.toUpperCase();

  RawMaterialType get sheet {
    switch (this) {
      case ss: return RawMaterialType.ssSheet;
      case brass: return RawMaterialType.brassSheet;
      case copper: return RawMaterialType.copperSheet;
    }
  }

  RawMaterialType get circle {
    switch (this) {
      case ss: return RawMaterialType.ssCircle;
      case brass: return RawMaterialType.brassCircle;
      case copper: return RawMaterialType.copperCircle;
    }
  }

  /// The stored type for this metal in the chosen form.
  RawMaterialType form({required bool isSheet}) => isSheet ? sheet : circle;
}

enum RawMaterialType {
  ssSheet, brassSheet, copperSheet,
  ssCircle, brassCircle, copperCircle;

  /// Which metal this is — used to total SS sheet + SS circle together.
  MaterialMetal get metal {
    switch (this) {
      case ssSheet:
      case ssCircle:
        return MaterialMetal.ss;
      case brassSheet:
      case brassCircle:
        return MaterialMetal.brass;
      case copperSheet:
      case copperCircle:
        return MaterialMetal.copper;
    }
  }

  String get displayName {
    switch (this) {
      case ssSheet: return 'SS Sheet';
      case brassSheet: return 'Brass Sheet';
      case copperSheet: return 'Copper Sheet';
      case ssCircle: return 'SS Circle';
      case brassCircle: return 'Brass Circle';
      case copperCircle: return 'Copper Circle';
    }
  }

  bool get isSheet => this == ssSheet || this == brassSheet || this == copperSheet;
  bool get isCircle => this == ssCircle || this == brassCircle || this == copperCircle;

  static RawMaterialType fromString(String s) {
    switch (s) {
      case 'SS Sheet': return ssSheet;
      case 'Brass Sheet': return brassSheet;
      case 'Copper Sheet': return copperSheet;
      case 'SS Circle': return ssCircle;
      case 'Brass Circle': return brassCircle;
      case 'Copper Circle': return copperCircle;
      default: return ssSheet;
    }
  }
}

class RawMaterialTransaction {
  final String? id;
  final RawMaterialType materialType;
  final DateTime date;
  final double quantityKg;
  final double ratePerKg;
  final String transactionType; // 'purchase' or 'sale'
  final String? supplierId;
  final String? supplierName;
  final bool isCredit;
  final double creditAmount;
  final String note;

  RawMaterialTransaction({
    this.id,
    required this.materialType,
    required this.date,
    required this.quantityKg,
    required this.ratePerKg,
    required this.transactionType,
    this.supplierId,
    this.supplierName,
    this.isCredit = false,
    this.creditAmount = 0,
    this.note = '',
  });

  double get totalValue => quantityKg * ratePerKg;

  Map<String, dynamic> toMap() => {
    'materialType': materialType.displayName,
    'date': date.toIso8601String().substring(0,10),
    'timestamp': date.millisecondsSinceEpoch,
    'quantityKg': quantityKg,
    'ratePerKg': ratePerKg,
    'transactionType': transactionType,
    'supplierId': supplierId,
    'supplierName': supplierName,
    'isCredit': isCredit,
    'creditAmount': creditAmount,
    'note': note,
  };

  factory RawMaterialTransaction.fromMap(String id, Map<String,dynamic> m) =>
      RawMaterialTransaction(
        id: id,
        materialType: RawMaterialType.fromString(m['materialType'] ?? 'SS Sheet'),
        date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
        quantityKg: (m['quantityKg'] as num?)?.toDouble() ?? 0,
        ratePerKg: (m['ratePerKg'] as num?)?.toDouble() ?? 0,
        transactionType: m['transactionType'] ?? 'purchase',
        supplierId: m['supplierId'],
        supplierName: m['supplierName'],
        isCredit: m['isCredit'] ?? false,
        creditAmount: (m['creditAmount'] as num?)?.toDouble() ?? 0,
        note: m['note'] ?? '',
      );
}

/// True when this row counts toward COMPANY stock. Party-linked rows are held
/// as a running balance on the party instead.
bool affectsCompanyStock(RawMaterialTransaction tx) =>
    tx.supplierId == null || tx.supplierId!.isEmpty;

/// How many kg this row moves company stock by.
///
/// Storage conventions this mirrors:
///   purchase    → adds
///   consumption → stored negative already, still a subtraction
///   sale        → subtracts
///   wastage     → subtracts (scrap is no longer usable sheet)
/// Anything unrecognised subtracts, which is the safe direction: an unknown
/// row can never silently inflate stock.
double companyStockDelta(RawMaterialTransaction tx) {
  if (!affectsCompanyStock(tx)) return 0;
  if (tx.transactionType == 'purchase') return tx.quantityKg.abs();
  return -tx.quantityKg.abs();
}

/// Total stock on show = company stock + what each party is holding.
///
/// Only POSITIVE party balances are added. A negative one means that party
/// owes sheet, and that shortfall was already taken out of company stock when
/// the sale was recorded — subtracting it again here would double-count it.
Map<RawMaterialType, double> combineTotalStock(
  Map<RawMaterialType, double> company,
  Iterable<PartyStock> parties,
) {
  final total = Map<RawMaterialType, double>.from(company);
  for (final party in parties) {
    party.stock.forEach((material, kg) {
      if (kg > 0) total[material] = (total[material] ?? 0) + kg;
    });
  }
  return total;
}

/// How much to add to a party's balance to undo [tx].
/// A purchase credited them sheet, so undoing it takes the sheet back.
double partyStockReversalKg(RawMaterialTransaction tx) =>
    tx.transactionType == 'purchase'
        ? -tx.quantityKg.abs()
        : tx.quantityKg.abs();

class Supplier {
  final String? id;
  final String name;
  final String phone;
  final String address;
  final bool isActive;

  Supplier({this.id, required this.name, this.phone = '', this.address = '', this.isActive = true});

  Map<String,dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'address': address,
    'isActive': isActive,
  };

  factory Supplier.fromMap(String id, Map<String,dynamic> m) => Supplier(
    id: id,
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    address: m['address'] ?? '',
    isActive: m['isActive'] ?? true,
  );
}

class SupplierCredit {
  final String supplierId;
  final String supplierName;
  double totalCredit;
  double totalPaid;
  double get outstanding => totalCredit - totalPaid;

  SupplierCredit({required this.supplierId, required this.supplierName, this.totalCredit = 0, this.totalPaid = 0});

  Map<String,dynamic> toMap() => {
    'supplierId': supplierId,
    'supplierName': supplierName,
    'totalCredit': totalCredit,
    'totalPaid': totalPaid,
  };

  factory SupplierCredit.fromMap(Map<String,dynamic> m) => SupplierCredit(
    supplierId: m['supplierId'] ?? '',
    supplierName: m['supplierName'] ?? '',
    totalCredit: (m['totalCredit'] as num?)?.toDouble() ?? 0,
    totalPaid: (m['totalPaid'] as num?)?.toDouble() ?? 0,
  );
}

class PartyStock {
  final String partyId;
  final String partyName;
  final String partyType; // 'buyer' or 'supplier'
  final Map<RawMaterialType, double> stock;

  PartyStock({
    required this.partyId,
    required this.partyName,
    required this.partyType,
    required this.stock,
  });

  Map<String, dynamic> toMap() => {
    'partyId': partyId,
    'partyName': partyName,
    'partyType': partyType,
    'stock': stock.map((k, v) => MapEntry(k.displayName, v)),
  };

  factory PartyStock.fromMap(String id, Map<String, dynamic> m) {
    final stockMap = (m['stock'] as Map<String, dynamic>?) ?? {};
    final stock = <RawMaterialType, double>{};
    for (var entry in stockMap.entries) {
      stock[RawMaterialType.fromString(entry.key)] = (entry.value as num).toDouble();
    }
    return PartyStock(
      partyId: m['partyId'] ?? '',
      partyName: m['partyName'] ?? '',
      partyType: m['partyType'] ?? '',
      stock: stock,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PATTARAI (shop / label name shown on screens and sale records — display
// only, does NOT create separate stock or filter any data).
// ══════════════════════════════════════════════════════════════════════════════
class Pattarai {
  final String? id;
  final String name;
  final bool isActive;
  final int sortOrder;

  const Pattarai({
    this.id,
    required this.name,
    this.isActive = false,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'isActive': isActive,
    'sortOrder': sortOrder,
  };

  factory Pattarai.fromMap(String id, Map<String, dynamic> m) => Pattarai(
    id: id,
    name: m['name'] ?? '',
    isActive: m['isActive'] ?? false,
    sortOrder: (m['sortOrder'] as num?)?.toInt() ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// PATTARAI STOCK — sheet issued to a workshop, pieces that come back, and the
// wastage settled later in bulk.
//
// ACCOUNTING RULES (the whole feature rests on these three):
//   issue   — sheet sent to the pattarai. The material is still yours, just at
//             the workshop, so company stock does NOT change. It only raises a
//             balance against that pattarai.
//   pieces  — finished pieces handed back. Reduces the pattarai balance.
//             Company stock does NOT change here either: the material leaves
//             stock when the finished product is SOLD, which the sale flow
//             already deducts.
//   wastage — settled monthly / every two months. This is the ONLY entry that
//             permanently destroys material, so it reduces the pattarai balance
//             AND company stock (via a linked raw-material transaction).
//
// So for 120 kg issued → 100 kg of pieces back → 20 kg wastage, the pattarai
// balance returns to zero and exactly 20 kg leaves company stock as loss.
// ══════════════════════════════════════════════════════════════════════════════
enum PattaraiTxType {
  issue, pieces, wastage;

  String get label {
    switch (this) {
      case issue: return 'Sheet sent';
      case pieces: return 'Pieces received';
      case wastage: return 'Wastage';
    }
  }

  /// issue adds to what the pattarai holds, the other two clear it down.
  bool get addsToPattarai => this == issue;

  static PattaraiTxType fromString(String s) {
    switch (s) {
      case 'pieces': return pieces;
      case 'wastage': return wastage;
      default: return issue;
    }
  }
}

class PattaraiStockTx {
  final String? id;
  final String pattaraiId;
  final String pattaraiName;
  final PattaraiTxType type;
  final RawMaterialType materialType;
  final double quantityKg; // always stored positive; [type] decides the sign
  final DateTime date;
  final String note;

  /// For wastage only — the rawMaterialTransactions doc that took this off
  /// company stock, so deleting the wastage can undo that too.
  final String? stockTxId;

  const PattaraiStockTx({
    this.id,
    required this.pattaraiId,
    required this.pattaraiName,
    required this.type,
    required this.materialType,
    required this.quantityKg,
    required this.date,
    this.note = '',
    this.stockTxId,
  });

  double get signedKg =>
      type.addsToPattarai ? quantityKg.abs() : -quantityKg.abs();

  Map<String, dynamic> toMap() => {
    'pattaraiId': pattaraiId,
    'pattaraiName': pattaraiName,
    'type': type.name,
    'materialType': materialType.displayName,
    'quantityKg': quantityKg,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
    'note': note,
    if (stockTxId != null) 'stockTxId': stockTxId,
  };

  factory PattaraiStockTx.fromMap(String id, Map<String, dynamic> m) =>
      PattaraiStockTx(
        id: id,
        pattaraiId: m['pattaraiId'] ?? '',
        pattaraiName: m['pattaraiName'] ?? '',
        type: PattaraiTxType.fromString(m['type'] ?? 'issue'),
        materialType: RawMaterialType.fromString(m['materialType'] ?? 'SS Sheet'),
        quantityKg: (m['quantityKg'] as num?)?.toDouble() ?? 0,
        date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
        note: m['note'] ?? '',
        stockTxId: m['stockTxId'] as String?,
      );
}

/// What one pattarai is holding, per metal.
class PattaraiBalance {
  final String pattaraiId;
  final String pattaraiName;
  double issued;
  double piecesBack;
  double wastage;

  PattaraiBalance({
    required this.pattaraiId,
    required this.pattaraiName,
    this.issued = 0,
    this.piecesBack = 0,
    this.wastage = 0,
  });

  /// Still at the workshop and not yet accounted for. Negative means more came
  /// back than was ever sent — a data-entry mistake worth showing.
  double get outstanding => issued - piecesBack - wastage;

  /// Share of the issued sheet lost as wastage, 0–1. Null until something has
  /// actually been issued.
  double? get wastagePercent => issued <= 0 ? null : wastage / issued;
}

/// Scrap sold off. Wastage is not thrown away — it piles up and is sold every
/// three to six months, so recorded wastage stays as a scrap balance until a
/// sale clears it. Company sheet stock is NOT touched here: the material
/// already left when the wastage was recorded.
class WastageSale {
  final String? id;
  final RawMaterialType materialType;
  final double quantityKg;
  final double ratePerKg;
  final DateTime date;
  final String buyerName;
  final String note;

  const WastageSale({
    this.id,
    required this.materialType,
    required this.quantityKg,
    required this.ratePerKg,
    required this.date,
    this.buyerName = '',
    this.note = '',
  });

  double get amount => quantityKg * ratePerKg;

  Map<String, dynamic> toMap() => {
    'materialType': materialType.displayName,
    'quantityKg': quantityKg,
    'ratePerKg': ratePerKg,
    'amount': amount,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
    'buyerName': buyerName,
    'note': note,
  };

  factory WastageSale.fromMap(String id, Map<String, dynamic> m) => WastageSale(
        id: id,
        materialType: RawMaterialType.fromString(m['materialType'] ?? 'SS Sheet'),
        quantityKg: (m['quantityKg'] as num?)?.toDouble() ?? 0,
        ratePerKg: (m['ratePerKg'] as num?)?.toDouble() ?? 0,
        date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
        buyerName: m['buyerName'] ?? '',
        note: m['note'] ?? '',
      );
}

/// Scrap sitting in the store: everything recorded as wastage, minus whatever
/// has been sold. Pass [metal] to limit it to one metal.
double wastageInStore(
  List<PattaraiStockTx> txs,
  List<WastageSale> sales, {
  MaterialMetal? metal,
}) {
  double collected = 0;
  for (final t in txs) {
    if (t.type != PattaraiTxType.wastage) continue;
    if (metal != null && t.materialType.metal != metal) continue;
    collected += t.quantityKg.abs();
  }
  double sold = 0;
  for (final s in sales) {
    if (metal != null && s.materialType.metal != metal) continue;
    sold += s.quantityKg.abs();
  }
  return collected - sold;
}

/// Money brought in by scrap sales, optionally for one metal.
double wastageSaleIncome(List<WastageSale> sales, {MaterialMetal? metal}) {
  double total = 0;
  for (final s in sales) {
    if (metal != null && s.materialType.metal != metal) continue;
    total += s.amount;
  }
  return total;
}

/// Rolls a flat list of entries into one balance per pattarai.
/// Pure function — no Firestore, so the arithmetic can be tested directly.
List<PattaraiBalance> computePattaraiBalances(
  List<PattaraiStockTx> txs, {
  MaterialMetal? metal,
}) {
  final byPattarai = <String, PattaraiBalance>{};
  for (final tx in txs) {
    if (metal != null && tx.materialType.metal != metal) continue;
    final b = byPattarai.putIfAbsent(
      tx.pattaraiId,
      () => PattaraiBalance(
          pattaraiId: tx.pattaraiId, pattaraiName: tx.pattaraiName),
    );
    switch (tx.type) {
      case PattaraiTxType.issue:
        b.issued += tx.quantityKg.abs();
        break;
      case PattaraiTxType.pieces:
        b.piecesBack += tx.quantityKg.abs();
        break;
      case PattaraiTxType.wastage:
        b.wastage += tx.quantityKg.abs();
        break;
    }
  }
  final list = byPattarai.values.toList()
    ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
  return list;
}

// ══════════════════════════════════════════════════════════════════════════════
// APP SETTINGS (Advanced settings — single document)
// ══════════════════════════════════════════════════════════════════════════════
class AppSettings {
  final double lowStockThresholdKg; // Inventory tab highlights a material red below this
  final Map<String, double> defaultRatesPerKg; // keyed by RawMaterialType.displayName

  // ── AI assistant ──────────────────────────────────────────────────────────
  // Your own Gemini API key (aistudio.google.com/apikey). When empty, the app
  // falls back to the key compiled into AiService.
  final String geminiApiKey;
  final String aiModel; // empty = use AiService's default model
  final String aiLanguage; // 'auto' | 'ta' | 'tanglish' | 'en'

  const AppSettings({
    this.lowStockThresholdKg = 0,
    this.defaultRatesPerKg = const {},
    this.geminiApiKey = '',
    this.aiModel = '',
    this.aiLanguage = 'auto',
  });

  Map<String, dynamic> toMap() => {
    'lowStockThresholdKg': lowStockThresholdKg,
    'defaultRatesPerKg': defaultRatesPerKg,
    'geminiApiKey': geminiApiKey,
    'aiModel': aiModel,
    'aiLanguage': aiLanguage,
  };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
    lowStockThresholdKg: (m['lowStockThresholdKg'] as num?)?.toDouble() ?? 0,
    defaultRatesPerKg: ((m['defaultRatesPerKg'] as Map<String, dynamic>?) ?? {})
        .map((k, v) => MapEntry(k, (v as num).toDouble())),
    geminiApiKey: m['geminiApiKey'] ?? '',
    aiModel: m['aiModel'] ?? '',
    aiLanguage: m['aiLanguage'] ?? 'auto',
  );

  AppSettings copyWith({
    double? lowStockThresholdKg,
    Map<String, double>? defaultRatesPerKg,
    String? geminiApiKey,
    String? aiModel,
    String? aiLanguage,
  }) => AppSettings(
    lowStockThresholdKg: lowStockThresholdKg ?? this.lowStockThresholdKg,
    defaultRatesPerKg: defaultRatesPerKg ?? this.defaultRatesPerKg,
    geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    aiModel: aiModel ?? this.aiModel,
    aiLanguage: aiLanguage ?? this.aiLanguage,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// BUSINESS PROFILE (NEW) — PAN, GST, address, bank details, and the
// payment QR (either uploaded as an image or auto-generated from a UPI ID).
// Stored as a single document, same pattern as AppSettings above. Lets you
// look up your own business details quickly when a customer asks.
// ══════════════════════════════════════════════════════════════════════════════
class BusinessProfile {
  final String businessName;
  final String pan;
  final String gst;
  final String address;
  final String phone;

  // Bank details
  final String bankAccountHolder;
  final String bankAccountNumber;
  final String bankIfsc;
  final String bankName;

  // QR / UPI
  final String upiId;
  // If the user uploaded their own QR image, this holds a base64-encoded
  // PNG/JPEG string (small images only — keep under ~700KB before encoding).
  // If empty, the UI auto-generates a QR from [upiId] instead.
  final String qrImageBase64;

  const BusinessProfile({
    this.businessName = '',
    this.pan = '',
    this.gst = '',
    this.address = '',
    this.phone = '',
    this.bankAccountHolder = '',
    this.bankAccountNumber = '',
    this.bankIfsc = '',
    this.bankName = '',
    this.upiId = '',
    this.qrImageBase64 = '',
  });

  bool get hasUploadedQr => qrImageBase64.isNotEmpty;
  bool get hasAnyQr => qrImageBase64.isNotEmpty || upiId.isNotEmpty;

  Map<String, dynamic> toMap() => {
    'businessName': businessName,
    'pan': pan,
    'gst': gst,
    'address': address,
    'phone': phone,
    'bankAccountHolder': bankAccountHolder,
    'bankAccountNumber': bankAccountNumber,
    'bankIfsc': bankIfsc,
    'bankName': bankName,
    'upiId': upiId,
    'qrImageBase64': qrImageBase64,
  };

  factory BusinessProfile.fromMap(Map<String, dynamic> m) => BusinessProfile(
    businessName: m['businessName'] ?? '',
    pan: m['pan'] ?? '',
    gst: m['gst'] ?? '',
    address: m['address'] ?? '',
    phone: m['phone'] ?? '',
    bankAccountHolder: m['bankAccountHolder'] ?? '',
    bankAccountNumber: m['bankAccountNumber'] ?? '',
    bankIfsc: m['bankIfsc'] ?? '',
    bankName: m['bankName'] ?? '',
    upiId: m['upiId'] ?? '',
    qrImageBase64: m['qrImageBase64'] ?? '',
  );

  BusinessProfile copyWith({
    String? businessName,
    String? pan,
    String? gst,
    String? address,
    String? phone,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? bankIfsc,
    String? bankName,
    String? upiId,
    String? qrImageBase64,
  }) => BusinessProfile(
    businessName: businessName ?? this.businessName,
    pan: pan ?? this.pan,
    gst: gst ?? this.gst,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
    bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    bankIfsc: bankIfsc ?? this.bankIfsc,
    bankName: bankName ?? this.bankName,
    upiId: upiId ?? this.upiId,
    qrImageBase64: qrImageBase64 ?? this.qrImageBase64,
  );
}