// lib/models/models.dart
// My Pattarii — Full cost model
// Labour 1-4, Runner 1-2, Polish 1-2, Vettu 1-2, Welding 1-2, Spinner 1-2
// Plasma (single), Varai (single), Material (single)
// Profit = (sellPrice - costPerKg) × qty  [or per piece for pcs products]
// Material is SUBTRACTED from sell price (it is a cost, not profit)

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
  // Material — raw material cost (subtracted from profit)
  final double costMaterial;
  // Plasma — single worker
  final double costPlasma;
  // Labour 1, 2, 3, 4
  final double costLabour1;
  final double costLabour2;
  final double costLabour3;
  final double costLabour4;
  // Vettu 1, 2
  final double costVettu1;
  final double costVettu2;
  // Welding 1, 2
  final double costWelding1;
  final double costWelding2;
  // Runner 1, 2
  final double costRunner1;
  final double costRunner2;
  // Varai (filing) — single
  final double costVarai;
  // Polish 1, 2
  final double costPolish1;
  final double costPolish2;
  // Spinner 1, 2
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
    this.costMaterial  = 0,
    this.costPlasma    = 0,
    this.costLabour1   = 0,
    this.costLabour2   = 0,
    this.costLabour3   = 0,
    this.costLabour4   = 0,
    this.costVettu1    = 0,
    this.costVettu2    = 0,
    this.costWelding1  = 0,
    this.costWelding2  = 0,
    this.costRunner1   = 0,
    this.costRunner2   = 0,
    this.costVarai     = 0,
    this.costPolish1   = 0,
    this.costPolish2   = 0,
    this.costSpinner1  = 0,
    this.costSpinner2  = 0,
  });

  // ── Derived values ────────────────────────────────────────────────────────
  // Total cost per piece (productWeightG grams)
  double get totalCostPerProduct =>
      costMaterial  + costPlasma   +
      costLabour1   + costLabour2  + costLabour3  + costLabour4  +
      costVettu1    + costVettu2   +
      costWelding1  + costWelding2 +
      costRunner1   + costRunner2  +
      costVarai     +
      costPolish1   + costPolish2  +
      costSpinner1  + costSpinner2;

  // Cost per kg = (totalCostPerProduct / productWeightG) * 1000
  double get costPerKg => totalCostPerProduct * (1000.0 / productWeightG);

  // Profit per kg = sellPricePerKg - costPerKg
  // (material, plasma, welding etc. are ALL costs so they ALL reduce profit)
  double get profitPerKg => sellPricePerKg - costPerKg;

  // Profit per piece = profitPerKg × (productWeightG / 1000)
  double get profitPerPiece => profitPerKg * (productWeightG / 1000.0);

  double get profitPerUnit  => soldByPiece ? profitPerPiece : profitPerKg;
  double profitForQty(double qty) => qty * profitPerUnit;

  // ── Worker cost map: role → cost per productWeightG grams ────────────────
  // Used for monthly salary calculation per product sold.
  // Only roles with cost > 0 are included.
  Map<String, double> get workerCostsPerProduct => {
    if (costPlasma   > 0) 'Plasma':    costPlasma,
    if (costLabour1  > 0) 'Labour 1':  costLabour1,
    if (costLabour2  > 0) 'Labour 2':  costLabour2,
    if (costLabour3  > 0) 'Labour 3':  costLabour3,
    if (costLabour4  > 0) 'Labour 4':  costLabour4,
    if (costVettu1   > 0) 'Vettu 1':   costVettu1,
    if (costVettu2   > 0) 'Vettu 2':   costVettu2,
    if (costWelding1 > 0) 'Welding 1': costWelding1,
    if (costWelding2 > 0) 'Welding 2': costWelding2,
    if (costRunner1  > 0) 'Runner 1':  costRunner1,
    if (costRunner2  > 0) 'Runner 2':  costRunner2,
    if (costVarai    > 0) 'Varai':     costVarai,
    if (costPolish1  > 0) 'Polish 1':  costPolish1,
    if (costPolish2  > 0) 'Polish 2':  costPolish2,
    if (costSpinner1 > 0) 'Spinner 1': costSpinner1,
    if (costSpinner2 > 0) 'Spinner 2': costSpinner2,
  };

  // ── Worker rates per KG (for storing at sale time) ───────────────────────
  Map<String, double> get workerRatesPerKg {
    final Map<String, double> result = {};
    workerCostsPerProduct.forEach((role, costPerPiece) {
      result[role] = costPerPiece * (1000.0 / productWeightG);
    });
    return result;
  }

  Map<String, dynamic> toMap() => {
    'name': name, 'category': category, 'padii': padii,
    'productWeightG': productWeightG, 'sellPricePerKg': sellPricePerKg,
    'soldByPiece': soldByPiece, 'unit': unit, 'isActive': isActive,
    'costMaterial':  costMaterial,
    'costPlasma':    costPlasma,
    'costLabour1':   costLabour1,
    'costLabour2':   costLabour2,
    'costLabour3':   costLabour3,
    'costLabour4':   costLabour4,
    'costVettu1':    costVettu1,
    'costVettu2':    costVettu2,
    'costWelding1':  costWelding1,
    'costWelding2':  costWelding2,
    'costRunner1':   costRunner1,
    'costRunner2':   costRunner2,
    'costVarai':     costVarai,
    'costPolish1':   costPolish1,
    'costPolish2':   costPolish2,
    'costSpinner1':  costSpinner1,
    'costSpinner2':  costSpinner2,
  };

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
    id: id,
    name:           m['name']          ?? '',
    category:       m['category']      ?? '',
    padii:          m['padii']         ?? '',
    productWeightG: (m['productWeightG'] as num?)?.toInt()    ?? 300,
    sellPricePerKg: (m['sellPricePerKg'] as num?)?.toDouble() ?? 0,
    soldByPiece:    m['soldByPiece']   ?? false,
    unit:           m['unit']          ?? 'kg',
    isActive:       m['isActive']      ?? true,
    costMaterial:  _d(m['costMaterial']),
    costPlasma:    _d(m['costPlasma']),
    costLabour1:   _d(m['costLabour1']),
    costLabour2:   _d(m['costLabour2']),
    costLabour3:   _d(m['costLabour3']),
    costLabour4:   _d(m['costLabour4']),
    costVettu1:    _d(m['costVettu1']),
    costVettu2:    _d(m['costVettu2']),
    costWelding1:  _d(m['costWelding1']),
    costWelding2:  _d(m['costWelding2']),
    costRunner1:   _d(m['costRunner1']),
    costRunner2:   _d(m['costRunner2']),
    costVarai:     _d(m['costVarai']),
    costPolish1:   _d(m['costPolish1']),
    costPolish2:   _d(m['costPolish2']),
    costSpinner1:  _d(m['costSpinner1']),
    costSpinner2:  _d(m['costSpinner2']),
  );

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  Product copyWith({
    String? id, String? name, String? category, String? padii,
    int? productWeightG, double? sellPricePerKg, bool? soldByPiece,
    String? unit, bool? isActive,
    double? costMaterial,  double? costPlasma,
    double? costLabour1,   double? costLabour2,  double? costLabour3,  double? costLabour4,
    double? costVettu1,    double? costVettu2,
    double? costWelding1,  double? costWelding2,
    double? costRunner1,   double? costRunner2,
    double? costVarai,
    double? costPolish1,   double? costPolish2,
    double? costSpinner1,  double? costSpinner2,
  }) => Product(
    id: id ?? this.id, name: name ?? this.name,
    category: category ?? this.category, padii: padii ?? this.padii,
    productWeightG: productWeightG ?? this.productWeightG,
    sellPricePerKg: sellPricePerKg ?? this.sellPricePerKg,
    soldByPiece: soldByPiece ?? this.soldByPiece, unit: unit ?? this.unit,
    isActive: isActive ?? this.isActive,
    costMaterial:  costMaterial  ?? this.costMaterial,
    costPlasma:    costPlasma    ?? this.costPlasma,
    costLabour1:   costLabour1   ?? this.costLabour1,
    costLabour2:   costLabour2   ?? this.costLabour2,
    costLabour3:   costLabour3   ?? this.costLabour3,
    costLabour4:   costLabour4   ?? this.costLabour4,
    costVettu1:    costVettu1    ?? this.costVettu1,
    costVettu2:    costVettu2    ?? this.costVettu2,
    costWelding1:  costWelding1  ?? this.costWelding1,
    costWelding2:  costWelding2  ?? this.costWelding2,
    costRunner1:   costRunner1   ?? this.costRunner1,
    costRunner2:   costRunner2   ?? this.costRunner2,
    costVarai:     costVarai     ?? this.costVarai,
    costPolish1:   costPolish1   ?? this.costPolish1,
    costPolish2:   costPolish2   ?? this.costPolish2,
    costSpinner1:  costSpinner1  ?? this.costSpinner1,
    costSpinner2:  costSpinner2  ?? this.costSpinner2,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// SALE
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
  // Worker cost map per kg stored at sale time for accurate monthly salary
  final Map<String, double> workerRatesPerKg;

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
  });

  Map<String, dynamic> toMap() => {
    'productId': productId, 'productName': productName,
    'productCategory': productCategory,
    'buyerId': buyerId, 'buyerName': buyerName,
    'qty': qty, 'salePrice': salePrice, 'profit': profit,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
    'workerRatesPerKg': workerRatesPerKg,
  };

  factory Sale.fromMap(String id, Map<String, dynamic> m) {
    final rawRates = m['workerRatesPerKg'] as Map<String, dynamic>? ?? {};
    final rates    = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));
    return Sale(
      id: id,
      productId:       m['productId']       ?? '',
      productName:     m['productName']     ?? '',
      productCategory: m['productCategory'] ?? '',
      buyerId:         m['buyerId'],
      buyerName:       m['buyerName'],
      qty:       (m['qty']       as num?)?.toDouble() ?? 0,
      salePrice: (m['salePrice'] as num?)?.toDouble() ?? 0,
      profit:    (m['profit']    as num?)?.toDouble() ?? 0,
      date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
      workerRatesPerKg: rates,
    );
  }
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
    this.id, required this.name,
    this.phone = '', this.address = '', this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name, 'phone': phone, 'address': address, 'isActive': isActive,
  };
  factory Buyer.fromMap(String id, Map<String, dynamic> m) => Buyer(
    id: id, name: m['name'] ?? '', phone: m['phone'] ?? '',
    address: m['address'] ?? '', isActive: m['isActive'] ?? true,
  );
  Buyer copyWith({String? id, String? name, String? phone,
      String? address, bool? isActive}) =>
      Buyer(id: id ?? this.id, name: name ?? this.name,
          phone: phone ?? this.phone, address: address ?? this.address,
          isActive: isActive ?? this.isActive);
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER
// Role must match a key in workerCostsPerProduct / workerRatesPerKg
// Valid roles: 'Labour 1','Labour 2','Labour 3','Labour 4',
//              'Runner 1','Runner 2','Polish 1','Polish 2',
//              'Vettu 1','Vettu 2','Welding 1','Welding 2',
//              'Spinner 1','Spinner 2','Plasma','Varai'
// ══════════════════════════════════════════════════════════════════════════════
class Worker {
  final String? id;
  final String name;
  final String role;
  final double dailyWage;
  final bool isActive;

  const Worker({
    this.id, required this.name, required this.role,
    required this.dailyWage, this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'name': name, 'role': role, 'dailyWage': dailyWage, 'isActive': isActive,
  };
  factory Worker.fromMap(String id, Map<String, dynamic> m) => Worker(
    id: id, name: m['name'] ?? '', role: m['role'] ?? '',
    dailyWage: (m['dailyWage'] as num?)?.toDouble() ?? 0,
    isActive: m['isActive'] ?? true,
  );
  Worker copyWith({String? id, String? name, String? role,
      double? dailyWage, bool? isActive}) =>
      Worker(id: id ?? this.id, name: name ?? this.name,
          role: role ?? this.role, dailyWage: dailyWage ?? this.dailyWage,
          isActive: isActive ?? this.isActive);
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
    this.id, required this.workerId, required this.workerName,
    required this.workerRole, required this.date,
    required this.present, required this.wage,
  });

  Map<String, dynamic> toMap() => {
    'workerId': workerId, 'workerName': workerName, 'workerRole': workerRole,
    'date': date.toIso8601String().substring(0, 10),
    'present': present, 'wage': wage,
  };
  factory WorkerAttendance.fromMap(String id, Map<String, dynamic> m) =>
      WorkerAttendance(
        id: id, workerId: m['workerId'] ?? '', workerName: m['workerName'] ?? '',
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
    this.id, required this.category, required this.description,
    required this.amount, required this.date,
  });

  Map<String, dynamic> toMap() => {
    'category': category, 'description': description, 'amount': amount,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
  };
  factory Expense.fromMap(String id, Map<String, dynamic> m) => Expense(
    id: id, category: m['category'] ?? '', description: m['description'] ?? '',
    amount: (m['amount'] as num?)?.toDouble() ?? 0,
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
  );
}