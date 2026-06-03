// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String get uid        => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  Future<UserCredential> register(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(name);
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name, 'email': email,
      'target': 30000,
      'createdAt': FieldValue.serverTimestamp(),
      'seeded': false,
    });
    await _seedProducts(cred.user!.uid);
    return cred;
  }

  Future<UserCredential> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    // Check if products exist — seed if missing (handles old accounts)
    await _ensureProductsSeeded(cred.user!.uid);
    return cred;
  }

  Future<void> logout() => _auth.signOut();
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Called on login to seed products if Firestore is empty for this user
  Future<void> _ensureProductsSeeded(String uid) async {
    try {
      final snap = await _db
          .collection('users').doc(uid)
          .collection('products')
          .limit(1).get();
      if (snap.docs.isEmpty) {
        print('No products found — seeding defaults');
        await _seedProducts(uid);
      } else {
        print('Products exist: ${snap.docs.length}');
      }
    } catch (e) {
      print('Seed check error: $e');
    }
  }

  Future<void> _seedProducts(String uid) async {
    final col   = _db.collection('users').doc(uid).collection('products');
    final batch = _db.batch();
    for (final p in _defaultProducts) {
      batch.set(col.doc(), p.toMap());
    }
    await batch.commit();
    print('Seeded ${_defaultProducts.length} default products');
  }

  static final _defaultProducts = [
    Product(name:'SS-I (1½ padii)',    category:'SS',    padii:'1½ padii',     productWeightG:500, sellPricePerKg:230, costLabour:7,   costPlasma:12.5, costWelding:4,  costRunner:8,  costVarai:8,  costPolish:44),
    Product(name:'SS-II (1 padii)',    category:'SS',    padii:'1 padii',      productWeightG:300, sellPricePerKg:230, costLabour:3.5, costPlasma:6.5,  costWelding:2,  costRunner:4,  costVarai:4,  costPolish:23),
    Product(name:'SS-III (½ padii)',   category:'SS',    padii:'½ padii',      productWeightG:300, sellPricePerKg:230, costLabour:3.5, costPlasma:6.5,  costWelding:2,  costRunner:4,  costVarai:4,  costPolish:23),
    Product(name:'SS-IV (¼ piece)',    category:'SS',    padii:'¼ piece',      productWeightG:100, sellPricePerKg:800, soldByPiece:true, unit:'pcs', costLabour:3.5, costPlasma:6.5, costWelding:2, costRunner:4, costVarai:4, costPolish:23, costMaterial:17),
    Product(name:'BR-II (1½ padii)',   category:'Brass', padii:'1½ padii',     productWeightG:700, sellPricePerKg:350, costLabour:10,  costVettu:7,    costWelding:10, costRunner:10, costVarai:10, costPolish:58),
    Product(name:'BR-III (1½+¼ padii)',category:'Brass', padii:'1½+¼ padii',   productWeightG:900, sellPricePerKg:350, costLabour:10,  costVettu:8,    costWelding:18, costRunner:15, costVarai:15, costPolish:82),
    Product(name:'BR-IV (¼ kg)',       category:'Brass', padii:'¼ kg',         productWeightG:200, sellPricePerKg:350, costLabour:5,   costVettu:2,    costWelding:7,  costRunner:5,  costVarai:5,  costPolish:24),
    Product(name:'BR-V (1 kg)',        category:'Brass', padii:'1 kg',         productWeightG:400, sellPricePerKg:350, costLabour:5,   costVettu:5,    costWelding:9,  costRunner:5,  costVarai:5,  costPolish:31),
    Product(name:'BR-VI (½ kg)',       category:'Brass', padii:'½ kg',         productWeightG:300, sellPricePerKg:350, costLabour:5,   costVettu:5,    costWelding:8,  costRunner:5,  costVarai:5,  costPolish:27),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS — all Firebase, no SQLite
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Product>> productsStream() =>
      _col('products')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((s) {
            final list = s.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
            list.sort((a, b) => a.category.compareTo(b.category));
            print('Products stream: ${list.length}');
            return list;
          });

  Future<List<Product>> getProducts() async {
    final q = await _col('products').where('isActive', isEqualTo: true).get();
    final list = q.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.category.compareTo(b.category));
    print('Products loaded: ${list.length}');
    return list;
  }

  Future<List<Product>> getAllProducts() async {
    final q = await _col('products').get();
    final list = q.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.category.compareTo(b.category));
    return list;
  }

  Future<void> saveProduct(Product p) async {
    if (p.id == null) {
      final ref = await _col('products').add(p.toMap());
      print('Product created: ${ref.id}');
    } else {
      await _col('products').doc(p.id).set(p.toMap()); // use set not update
      print('Product updated: ${p.id}');
    }
  }

  Future<void> deactivateProduct(String id) =>
      _col('products').doc(id).update({'isActive': false});

  // ══════════════════════════════════════════════════════════════════════════
  // SALES
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> addSale(Sale sale) async {
    final ref = await _col('sales').add(sale.toMap());
    print('Sale added: ${ref.id}');
    return ref.id;
  }

  Future<void> deleteSale(String id) => _col('sales').doc(id).delete();

  Future<List<Sale>> salesForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final q = await _col('sales').where('date', isEqualTo: dateStr).get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<List<Sale>> salesForMonth(int year, int month) async {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final q = await _col('sales')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo:   '$y-$m-31')
        .get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<List<Sale>> salesForBuyer(String buyerId) async {
    final q = await _col('sales').where('buyerId', isEqualTo: buyerId).get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<double> monthlyTotalProfit(int year, int month) async {
    final sales = await salesForMonth(year, month);
    return sales.fold<double>(
  0.0,
  (sum, sale) => sum + (sale.profit ?? 0),
);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUYERS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Buyer>> buyersStream() =>
      _col('buyers').where('isActive', isEqualTo: true).snapshots().map((s) {
        final list = s.docs.map((d) => Buyer.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Future<List<Buyer>> getBuyers() async {
    final q = await _col('buyers').where('isActive', isEqualTo: true).get();
    final list = q.docs.map((d) => Buyer.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    print('Buyers loaded: ${list.length}');
    return list;
  }

  Future<void> saveBuyer(Buyer b) async {
    if (b.id == null) {
      await _col('buyers').add(b.toMap());
    } else {
      await _col('buyers').doc(b.id).set(b.toMap());
    }
  }

  Future<void> deleteBuyer(String id) =>
      _col('buyers').doc(id).update({'isActive': false});

  Future<BuyerSummary> buyerSummary(String buyerId) async {
    final sales = await salesForBuyer(buyerId);
    double totalKg = 0, totalRevenue = 0, totalProfit = 0;
    for (final s in sales) {
      totalKg      += s.qty;
      totalRevenue += s.qty * s.salePrice;
      totalProfit  += s.profit;
    }
    return BuyerSummary(salesCount: sales.length, totalKg: totalKg,
        totalRevenue: totalRevenue, totalProfit: totalProfit, sales: sales);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WORKERS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Worker>> workersStream() =>
      _col('workers').where('isActive', isEqualTo: true).snapshots().map((s) {
        final list = s.docs.map((d) => Worker.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  Future<List<Worker>> getWorkers() async {
    final q = await _col('workers').where('isActive', isEqualTo: true).get();
    final list = q.docs.map((d) => Worker.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<void> saveWorker(Worker w) async {
    if (w.id == null) {
      await _col('workers').add(w.toMap());
    } else {
      await _col('workers').doc(w.id).set(w.toMap());
    }
  }

  Future<void> deleteWorker(String id) =>
      _col('workers').doc(id).update({'isActive': false});

  Future<void> saveAttendance(WorkerAttendance a) async {
    final dateStr = a.date.toIso8601String().substring(0, 10);
    final q = await _col('attendance')
        .where('workerId', isEqualTo: a.workerId)
        .where('date',     isEqualTo: dateStr).get();
    if (q.docs.isEmpty) {
      await _col('attendance').add(a.toMap());
    } else {
      await _col('attendance').doc(q.docs.first.id).set(a.toMap());
    }
  }

  Future<List<WorkerAttendance>> attendanceForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final q = await _col('attendance').where('date', isEqualTo: dateStr).get();
    return q.docs.map((d) => WorkerAttendance.fromMap(d.id, d.data())).toList();
  }

  Future<List<WorkerAttendance>> attendanceForMonth(int year, int month) async {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final q = await _col('attendance')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo:   '$y-$m-31').get();
    final list = q.docs.map((d) => WorkerAttendance.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WORKER WAGE RATES — per kg sold (auto wage from sales)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, double>> getWageRates() async {
    final doc  = await _db.collection('users').doc(uid).get();
    final raw  = (doc.data()?['wageRates'] as Map<String, dynamic>?) ?? {};
    return {
      'Labour':  (raw['Labour']  as num?)?.toDouble() ?? 15.0,
      'Runner':  (raw['Runner']  as num?)?.toDouble() ?? 8.0,
      'Varai':   (raw['Varai']   as num?)?.toDouble() ?? 8.0,
      'Plasma':  (raw['Plasma']  as num?)?.toDouble() ?? 12.5,
      'Welding': (raw['Welding'] as num?)?.toDouble() ?? 4.0,
      'Polish':  (raw['Polish']  as num?)?.toDouble() ?? 44.0,
    };
  }

  Future<void> saveWageRates(Map<String, double> rates) async =>
      _db.collection('users').doc(uid).update({'wageRates': rates});

  /// Calculate auto wages per worker from total kg sold this month
  Future<List<WorkerAutoWage>> autoWagesForMonth(int year, int month) async {
    final results = await Future.wait([
      getWorkers(), salesForMonth(year, month), getWageRates(),
    ]);
    final workers   = results[0] as List<Worker>;
    final sales     = results[1] as List<Sale>;
    final wageRates = results[2] as Map<String, double>;
    final totalKg   = sales.fold(0.0, (s, x) => s + x.qty);
    return workers.map((w) {
      final ratePerKg = wageRates[w.role] ?? 0;
      return WorkerAutoWage(
          worker: w, totalKg: totalKg,
          ratePerKg: ratePerKg, autoWage: ratePerKg * totalKg);
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPENSES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addExpense(Expense e) => _col('expenses').add(e.toMap());
  Future<void> deleteExpense(String id) => _col('expenses').doc(id).delete();

  Future<List<Expense>> expensesForMonth(int year, int month) async {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final q = await _col('expenses')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo:   '$y-$m-31').get();
    final list = q.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MONTHLY SUMMARY — all queries in parallel
  // ══════════════════════════════════════════════════════════════════════════

  Future<MonthlySummary> monthlySummary(int year, int month) async {
    final results = await Future.wait([
      salesForMonth(year, month),
      expensesForMonth(year, month),
      attendanceForMonth(year, month),
      autoWagesForMonth(year, month),
    ]);
    final sales      = results[0] as List<Sale>;
    final expenses   = results[1] as List<Expense>;
    final attendance = results[2] as List<WorkerAttendance>;
    final autoWages  = results[3] as List<WorkerAutoWage>;

    final totalProfit   = sales.fold(0.0,    (s, x) => s + x.profit);
    final totalRevenue  = sales.fold(0.0,    (s, x) => s + x.qty * x.salePrice);
    final totalKg       = sales.fold(0.0,    (s, x) => s + x.qty);
    final totalExpenses = expenses.fold(0.0, (s, x) => s + x.amount);
    final attendWages   = attendance.where((a) => a.present)
        .fold(0.0, (s, a) => s + a.wage);
    final autoWageTotal = autoWages.fold(0.0, (s, w) => s + w.autoWage);

    final Map<String, double> dailyMap   = {};
    final Map<String, double> productMap = {};
    final Map<String, BuyerMonthSummary> buyerMapInternal = {};
    final Map<String, double> expenseCatMap = {};

    for (final s in sales) {
      final dk = s.date.toIso8601String().substring(0, 10);
      dailyMap[dk] = (dailyMap[dk] ?? 0) + s.profit;
      final pk = '${s.productId}|${s.productName}';
      productMap[pk] = (productMap[pk] ?? 0) + s.profit;
      if (s.buyerId != null && s.buyerId!.isNotEmpty) {
        buyerMapInternal[s.buyerId!] ??= BuyerMonthSummary(
            buyerId: s.buyerId!, buyerName: s.buyerName ?? 'Unknown');
        buyerMapInternal[s.buyerId!]!.add(s);
      }
    }
    for (final e in expenses) {
      expenseCatMap[e.category] = (expenseCatMap[e.category] ?? 0) + e.amount;
    }

    return MonthlySummary(
      sales: sales, expenses: expenses, attendance: attendance,
      autoWages: autoWages, totalProfit: totalProfit,
      totalRevenue: totalRevenue, totalKg: totalKg,
      totalExpenses: totalExpenses, attendanceWages: attendWages,
      autoWageTotal: autoWageTotal,
      netProfit: totalProfit - totalExpenses,
      dailyMap: dailyMap, productMap: productMap,
      buyerList: buyerMapInternal.values.toList()
          ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit)),
      expenseCatMap: expenseCatMap,
    );
  }
}

// ── Data classes ──────────────────────────────────────────────────────────────
class BuyerSummary {
  final int salesCount;
  final double totalKg, totalRevenue, totalProfit;
  final List<Sale> sales;
  const BuyerSummary({required this.salesCount, required this.totalKg,
      required this.totalRevenue, required this.totalProfit, required this.sales});
}

class BuyerMonthSummary {
  final String buyerId, buyerName;
  int salesCount = 0;
  double totalKg = 0, totalRevenue = 0, totalProfit = 0;
  BuyerMonthSummary({required this.buyerId, required this.buyerName});
  void add(Sale s) {
    salesCount++; totalKg += s.qty;
    totalRevenue += s.qty * s.salePrice; totalProfit += s.profit;
  }
}

class WorkerAutoWage {
  final Worker worker;
  final double totalKg, ratePerKg, autoWage;
  const WorkerAutoWage({required this.worker, required this.totalKg,
      required this.ratePerKg, required this.autoWage});
}

class MonthlySummary {
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<WorkerAttendance> attendance;
  final List<WorkerAutoWage> autoWages;
  final double totalProfit, totalRevenue, totalKg;
  final double totalExpenses, attendanceWages, autoWageTotal, netProfit;
  final Map<String, double> dailyMap, productMap, expenseCatMap;
  final List<BuyerMonthSummary> buyerList;
  const MonthlySummary({
    required this.sales, required this.expenses,
    required this.attendance, required this.autoWages,
    required this.totalProfit, required this.totalRevenue, required this.totalKg,
    required this.totalExpenses, required this.attendanceWages,
    required this.autoWageTotal, required this.netProfit,
    required this.dailyMap, required this.productMap,
    required this.buyerList, required this.expenseCatMap,
  });
}