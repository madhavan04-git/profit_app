// lib/models/models.dart
// ─────────────────────────────────────────────────────────────────────────────
// Single file for all data models used in the app.
// Every model has: toMap() for Firestore, fromMap() factory, copyWith().
// ─────────────────────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════════════════════
// PRODUCT
// ══════════════════════════════════════════════════════════════════════════════
class Product {
  final String? id;          // Firestore document ID
  final String name;
  final String category;     // 'SS', 'Brass', or any custom
  final String padii;
  final int productWeightG;
  final double sellPricePerKg;
  final bool soldByPiece;
  final String unit;         // 'kg' or 'pcs'
  final double costLabour;
  final double costPlasma;
  final double costVettu;
  final double costWelding;
  final double costRunner;
  final double costVarai;
  final double costPolish;
  final double costMaterial;
  final bool isActive;

  const Product({
    this.id,
    required this.name,
    required this.category,
    this.padii = '',
    required this.productWeightG,
    required this.sellPricePerKg,
    this.soldByPiece = false,
    this.unit = 'kg',
    this.costLabour = 0,
    this.costPlasma = 0,
    this.costVettu = 0,
    this.costWelding = 0,
    this.costRunner = 0,
    this.costVarai = 0,
    this.costPolish = 0,
    this.costMaterial = 0,
    this.isActive = true,
  });

  double get totalCostPerProduct =>
      costLabour + costPlasma + costVettu + costWelding +
      costRunner + costVarai + costPolish + costMaterial;

  double get costPerKg        => totalCostPerProduct * (1000 / productWeightG);
  double get profitPerKg      => sellPricePerKg - costPerKg;
  double get profitPerPiece   => profitPerKg * (productWeightG / 1000);
  double get profitPerUnit    => soldByPiece ? profitPerPiece : profitPerKg;
  double profitForQty(double qty) => qty * profitPerUnit;

  Map<String, dynamic> toMap() => {
    'name': name, 'category': category, 'padii': padii,
    'productWeightG': productWeightG, 'sellPricePerKg': sellPricePerKg,
    'soldByPiece': soldByPiece, 'unit': unit,
    'costLabour': costLabour, 'costPlasma': costPlasma, 'costVettu': costVettu,
    'costWelding': costWelding, 'costRunner': costRunner, 'costVarai': costVarai,
    'costPolish': costPolish, 'costMaterial': costMaterial, 'isActive': isActive,
  };

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
    id: id, name: m['name'] ?? '', category: m['category'] ?? '',
    padii: m['padii'] ?? '', productWeightG: (m['productWeightG'] ?? 300) as int,
    sellPricePerKg: (m['sellPricePerKg'] as num?)?.toDouble() ?? 0,
    soldByPiece: m['soldByPiece'] ?? false, unit: m['unit'] ?? 'kg',
    costLabour: (m['costLabour'] as num?)?.toDouble() ?? 0,
    costPlasma: (m['costPlasma'] as num?)?.toDouble() ?? 0,
    costVettu: (m['costVettu'] as num?)?.toDouble() ?? 0,
    costWelding: (m['costWelding'] as num?)?.toDouble() ?? 0,
    costRunner: (m['costRunner'] as num?)?.toDouble() ?? 0,
    costVarai: (m['costVarai'] as num?)?.toDouble() ?? 0,
    costPolish: (m['costPolish'] as num?)?.toDouble() ?? 0,
    costMaterial: (m['costMaterial'] as num?)?.toDouble() ?? 0,
    isActive: m['isActive'] ?? true,
  );

  Product copyWith({
    String? id, String? name, String? category, String? padii,
    int? productWeightG, double? sellPricePerKg, bool? soldByPiece, String? unit,
    double? costLabour, double? costPlasma, double? costVettu, double? costWelding,
    double? costRunner, double? costVarai, double? costPolish, double? costMaterial,
    bool? isActive,
  }) => Product(
    id: id ?? this.id, name: name ?? this.name, category: category ?? this.category,
    padii: padii ?? this.padii, productWeightG: productWeightG ?? this.productWeightG,
    sellPricePerKg: sellPricePerKg ?? this.sellPricePerKg,
    soldByPiece: soldByPiece ?? this.soldByPiece, unit: unit ?? this.unit,
    costLabour: costLabour ?? this.costLabour, costPlasma: costPlasma ?? this.costPlasma,
    costVettu: costVettu ?? this.costVettu, costWelding: costWelding ?? this.costWelding,
    costRunner: costRunner ?? this.costRunner, costVarai: costVarai ?? this.costVarai,
    costPolish: costPolish ?? this.costPolish, costMaterial: costMaterial ?? this.costMaterial,
    isActive: isActive ?? this.isActive,
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
  final String? buyerId;       // optional — link to a buyer
  final String? buyerName;
  final double qty;
  final double salePrice;      // actual sale price used (can differ from default)
  final double profit;
  final DateTime date;

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
  });

  Map<String, dynamic> toMap() => {
    'productId': productId, 'productName': productName,
    'productCategory': productCategory,
    'buyerId': buyerId, 'buyerName': buyerName,
    'qty': qty, 'salePrice': salePrice, 'profit': profit,
    'date': date.toIso8601String().substring(0, 10),
    'timestamp': date.millisecondsSinceEpoch,
  };

  factory Sale.fromMap(String id, Map<String, dynamic> m) => Sale(
    id: id, productId: m['productId'] ?? '',
    productName: m['productName'] ?? '', productCategory: m['productCategory'] ?? '',
    buyerId: m['buyerId'], buyerName: m['buyerName'],
    qty: (m['qty'] as num?)?.toDouble() ?? 0,
    salePrice: (m['salePrice'] as num?)?.toDouble() ?? 0,
    profit: (m['profit'] as num?)?.toDouble() ?? 0,
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
  );
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
    'name': name, 'phone': phone, 'address': address, 'isActive': isActive,
  };

  factory Buyer.fromMap(String id, Map<String, dynamic> m) => Buyer(
    id: id, name: m['name'] ?? '', phone: m['phone'] ?? '',
    address: m['address'] ?? '', isActive: m['isActive'] ?? true,
  );

  Buyer copyWith({String? id, String? name, String? phone,
      String? address, bool? isActive}) => Buyer(
    id: id ?? this.id, name: name ?? this.name,
    phone: phone ?? this.phone, address: address ?? this.address,
    isActive: isActive ?? this.isActive,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER
// ══════════════════════════════════════════════════════════════════════════════
class Worker {
  final String? id;
  final String name;
  final String role;   // e.g. 'Labour', 'Plasma', 'Welding'
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
    'name': name, 'role': role, 'dailyWage': dailyWage, 'isActive': isActive,
  };

  factory Worker.fromMap(String id, Map<String, dynamic> m) => Worker(
    id: id, name: m['name'] ?? '', role: m['role'] ?? '',
    dailyWage: (m['dailyWage'] as num?)?.toDouble() ?? 0,
    isActive: m['isActive'] ?? true,
  );

  Worker copyWith({String? id, String? name, String? role,
      double? dailyWage, bool? isActive}) => Worker(
    id: id ?? this.id, name: name ?? this.name,
    role: role ?? this.role, dailyWage: dailyWage ?? this.dailyWage,
    isActive: isActive ?? this.isActive,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// WORKER ATTENDANCE (daily record of days worked per worker)
// ══════════════════════════════════════════════════════════════════════════════
class WorkerAttendance {
  final String? id;
  final String workerId;
  final String workerName;
  final String workerRole;
  final DateTime date;
  final bool present;
  final double wage; // wage for that day

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
    'workerId': workerId, 'workerName': workerName, 'workerRole': workerRole,
    'date': date.toIso8601String().substring(0, 10),
    'present': present, 'wage': wage,
  };

  factory WorkerAttendance.fromMap(String id, Map<String, dynamic> m) => WorkerAttendance(
    id: id, workerId: m['workerId'] ?? '', workerName: m['workerName'] ?? '',
    workerRole: m['workerRole'] ?? '',
    date: m['date'] != null ? DateTime.parse(m['date']) : DateTime.now(),
    present: m['present'] ?? false,
    wage: (m['wage'] as num?)?.toDouble() ?? 0,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// EXPENSE (material/overhead costs)
// ══════════════════════════════════════════════════════════════════════════════
class Expense {
  final String? id;
  final String category;   // 'Material', 'Runner', 'Varai', 'Plasma', 'Other'
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