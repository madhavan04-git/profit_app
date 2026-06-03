// lib/services/firebase_service.dart
// My Pattarii
// KEY FEATURES:
// 1. Device license check — app cannot be used on unlicensed devices
// 2. Worker salary calculated PER PRODUCT from sales (not attendance alone)
//    e.g. 20 kg sold → Plasma worker earns: plasma_rate_per_kg × 20
// 3. Logout support
// 4. All 17 cost fields: Material, Plasma, Labour 1-4, Vettu 1-2,
//    Welding 1-2, Runner 1-2, Varai, Polish 1-2, Spinner 1-2

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
  // DEVICE LICENSE — prevents sharing without permission
  // Each Firebase account is locked to the device(s) it first logged in on.
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return android.id;
      }
      return 'unknown-platform';
    } catch (_) { return 'unknown'; }
  }

  /// Register current device to this account (called on login/register)
  Future<void> registerDevice() async {
    final deviceId = await _getDeviceId();
    final userDoc  = _db.collection('users').doc(uid);
    final snap     = await userDoc.get();
    final data     = snap.data() ?? {};
    final List<dynamic> devices = data['registeredDevices'] ?? [];
    if (!devices.contains(deviceId)) {
      devices.add(deviceId);
      await userDoc.set({'registeredDevices': devices});
    }
  }

  /// Returns true if current device is licensed for this account.
  /// On first login (no devices registered), auto-registers and returns true.
  Future<bool> isDeviceLicensed() async {
    try {
      final deviceId = await _getDeviceId();
      final snap = await _db.collection('users').doc(uid).get();
      final data = snap.data() ?? {};
      final List<dynamic> devices = data['registeredDevices'] ?? [];
      if (devices.isEmpty) {
        await registerDevice();
        return true;
      }
      return devices.contains(deviceId);
    } catch (_) { return false; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH
  // ══════════════════════════════════════════════════════════════════════════

  Future<UserCredential> register(String email, String password, String name) async {
    print("AUTH SUCCESS");
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user!.updateDisplayName(name);

    final deviceId = await _getDeviceId();

    print("DISPLAY NAME UPDATED");

    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name, 'email': email, 'target': 30000,
      'createdAt': FieldValue.serverTimestamp(),
      'registeredDevices': [deviceId],
    });
    await _seedProducts(cred.user!.uid);

     print("FIRESTORE SUCCESS");

    return cred;
  }

  Future<UserCredential> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    await _ensureSeeded(cred.user!.uid);
    await registerDevice();
    return cred;
  }

  /// Logout — signs out from Firebase Auth
  Future<void> logout() => _auth.signOut();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureSeeded(String uid) async {
    final snap = await _db.collection('users').doc(uid)
        .collection('products').limit(1).get();
    if (snap.docs.isEmpty) await _seedProducts(uid);
  }

  Future<void> _seedProducts(String uid) async {
    final col   = _db.collection('users').doc(uid).collection('products');
    final batch = _db.batch();
    for (final p in _defaultProducts) batch.set(col.doc(), p.toMap());
    await batch.commit();
  }

  static final _defaultProducts = [
    Product(name:'SS-I (1½ padii)',     category:'SS',    padii:'1½ padii',
        productWeightG:500, sellPricePerKg:230,
        costLabour1:7, costPlasma:12.5, costWelding1:4, costRunner1:8,
        costVarai:8, costPolish1:44),
    Product(name:'SS-II (1 padii)',     category:'SS',    padii:'1 padii',
        productWeightG:300, sellPricePerKg:230,
        costLabour1:3.5, costPlasma:6.5, costWelding1:2, costRunner1:4,
        costVarai:4, costPolish1:23),
    Product(name:'SS-III (½ padii)',    category:'SS',    padii:'½ padii',
        productWeightG:300, sellPricePerKg:230,
        costLabour1:3.5, costPlasma:6.5, costWelding1:2, costRunner1:4,
        costVarai:4, costPolish1:23),
    Product(name:'SS-IV (¼ piece)',     category:'SS',    padii:'¼ piece',
        productWeightG:100, sellPricePerKg:800,
        soldByPiece:true, unit:'pcs',
        costMaterial:17, costLabour1:3.5, costPlasma:6.5,
        costWelding1:2, costRunner1:4, costVarai:4, costPolish1:23),
    Product(name:'BR-II (1½ padii)',    category:'Brass', padii:'1½ padii',
        productWeightG:700, sellPricePerKg:350,
        costLabour1:10, costVettu1:7, costWelding1:10,
        costRunner1:10, costVarai:10, costPolish1:58),
    Product(name:'BR-III (1½+¼ padii)',category:'Brass', padii:'1½+¼ padii',
        productWeightG:900, sellPricePerKg:350,
        costLabour1:10, costVettu1:8, costWelding1:18,
        costRunner1:15, costVarai:15, costPolish1:82),
    Product(name:'BR-IV (¼ kg)',        category:'Brass', padii:'¼ kg',
        productWeightG:200, sellPricePerKg:350,
        costLabour1:5, costVettu1:2, costWelding1:7,
        costRunner1:5, costVarai:5, costPolish1:24),
    Product(name:'BR-V (1 kg)',         category:'Brass', padii:'1 kg',
        productWeightG:400, sellPricePerKg:350,
        costLabour1:5, costVettu1:5, costWelding1:9,
        costRunner1:5, costVarai:5, costPolish1:31),
    Product(name:'BR-VI (½ kg)',        category:'Brass', padii:'½ kg',
        productWeightG:300, sellPricePerKg:350,
        costLabour1:5, costVettu1:5, costWelding1:8,
        costRunner1:5, costVarai:5, costPolish1:27),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Product>> productsStream() =>
      _col('products').where('isActive', isEqualTo: true).snapshots().map((s) {
        final list = s.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.category.compareTo(b.category));
        return list;
      });

  Future<List<Product>> getProducts() async {
    final q = await _col('products').where('isActive', isEqualTo: true).get();
    final list = q.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.category.compareTo(b.category));
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
      await _col('products').add(p.toMap());
    } else {
      await _col('products').doc(p.id).set(p.toMap());
    }
  }

  Future<void> deactivateProduct(String id) =>
      _col('products').doc(id).update({'isActive': false});

  // ══════════════════════════════════════════════════════════════════════════
  // SALES — worker rates per kg stored at sale time for accurate salary calc
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> addSale(Sale sale) async {
    final ref = await _col('sales').add(sale.toMap());
    return ref.id;
  }

  Future<void> deleteSale(String id) => _col('sales').doc(id).delete();

  Future<List<Sale>> salesForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final q = await _col('sales').where('date', isEqualTo: dateStr).get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => (b.date.millisecondsSinceEpoch)
        .compareTo(a.date.millisecondsSinceEpoch));
    return list;
  }

  Future<List<Sale>> salesForMonth(int year, int month) async {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final q = await _col('sales')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo:   '$y-$m-31').get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<double> monthlyTotalProfit(int year, int month) async {
    final sales = await salesForMonth(year, month);
 return sales.fold<double>(
    0.0,
    (sum, sale) => sum + sale.profit,
  );  }

  Future<List<Sale>> salesForBuyer(String buyerId) async {
    final q = await _col('sales').where('buyerId', isEqualTo: buyerId).get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
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
    return list;
  }

  Future<void> saveBuyer(Buyer b) async {
    if (b.id == null) await _col('buyers').add(b.toMap());
    else await _col('buyers').doc(b.id).set(b.toMap());
  }

  Future<void> deleteBuyer(String id) =>
      _col('buyers').doc(id).update({'isActive': false});

  // ══════════════════════════════════════════════════════════════════════════
  // WORKERS
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Worker>> workersStream() =>
      _col('workers').where('isActive', isEqualTo: true).snapshots().map((s) {
        final list = s.docs.map((d) => Worker.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.role.compareTo(b.role));
        return list;
      });

  Future<List<Worker>> getWorkers() async {
    final q = await _col('workers').where('isActive', isEqualTo: true).get();
    final list = q.docs.map((d) => Worker.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.role.compareTo(b.role));
    return list;
  }

  Future<void> saveWorker(Worker w) async {
    if (w.id == null) await _col('workers').add(w.toMap());
    else await _col('workers').doc(w.id).set(w.toMap());
  }

  Future<void> deleteWorker(String id) =>
      _col('workers').doc(id).update({'isActive': false});

  // ── Attendance ─────────────────────────────────────────────────────────────

  Future<void> saveAttendance(WorkerAttendance a) async {
    final dateStr = a.date.toIso8601String().substring(0, 10);
    final q = await _col('attendance')
        .where('workerId', isEqualTo: a.workerId)
        .where('date',     isEqualTo: dateStr).get();
    if (q.docs.isEmpty) await _col('attendance').add(a.toMap());
    else await _col('attendance').doc(q.docs.first.id).set(a.toMap());
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
  // MONTHLY SUMMARY
  // Worker salary = sum of (workerRatePerKg × qty) per sale
  // Only workers whose role matches a product cost field are paid.
  // e.g. 20 kg SS-I sold → Plasma worker earns: 12.5/piece × (1000/500) × 20 = Rs 500
  // ══════════════════════════════════════════════════════════════════════════

  Future<MonthlySummary> monthlySummary(int year, int month) async {
    final results = await Future.wait([
      salesForMonth(year, month),
      expensesForMonth(year, month),
      attendanceForMonth(year, month),
      getWorkers(),
    ]);
    final sales      = results[0] as List<Sale>;
    final expenses   = results[1] as List<Expense>;
    final attendance = results[2] as List<WorkerAttendance>;
    final workers    = results[3] as List<Worker>;

    final totalProfit   = sales.fold(0.0,    (s, x) => s + x.profit);
    final totalRevenue  = sales.fold(0.0,    (s, x) => s + x.qty * x.salePrice);
    final totalKg       = sales.fold(0.0,    (s, x) => s + x.qty);
    final totalExpenses = expenses.fold(0.0, (s, x) => s + x.amount);
    final attendWages   = attendance.where((a) => a.present)
        .fold(0.0, (s, a) => s + a.wage);

    // ── PRODUCT-BASED WORKER SALARY ──────────────────────────────────────
    // For each sale: worker earned = workerRatePerKg × qty sold
    final Map<String, double> autoWageByRole = {};
    for (final sale in sales) {
      sale.workerRatesPerKg.forEach((role, ratePerKg) {
        autoWageByRole[role] = (autoWageByRole[role] ?? 0) + ratePerKg * sale.qty;
      });
    }

    // Match role to named workers
    final List<WorkerAutoWage> autoWages = [];
    final Set<String> matchedRoles = {};
    for (final w in workers) {
      final wage = autoWageByRole[w.role] ?? 0;
      if (wage > 0) {
        matchedRoles.add(w.role);
        autoWages.add(WorkerAutoWage(worker: w, totalKg: totalKg,
            ratePerKg: 0, autoWage: wage));
      }
    }
    // Add any roles in sales that have no named worker
    autoWageByRole.forEach((role, wage) {
      if (!matchedRoles.contains(role)) {
        autoWages.add(WorkerAutoWage(
            worker: Worker(name: role, role: role, dailyWage: 0),
            totalKg: totalKg, ratePerKg: 0, autoWage: wage));
      }
    });
    final autoWageTotal = autoWageByRole.values.fold(0.0, (s, v) => s + v);

    // Maps for charts/tables
    final Map<String, double>   dailyMap      = {};
    final Map<String, double>   productMap    = {};
    final Map<String, BuyerMonthSummary> buyerMapI = {};
    final Map<String, double>   expenseCatMap = {};

    for (final s in sales) {
      final dk = s.date.toIso8601String().substring(0, 10);
      dailyMap[dk] = (dailyMap[dk] ?? 0) + s.profit;
      final pk = '${s.productId}|${s.productName}';
      productMap[pk] = (productMap[pk] ?? 0) + s.profit;
      if (s.buyerId != null && s.buyerId!.isNotEmpty) {
        buyerMapI[s.buyerId!] ??= BuyerMonthSummary(
            buyerId: s.buyerId!, buyerName: s.buyerName ?? 'Unknown');
        buyerMapI[s.buyerId!]!.add(s);
      }
    }
    for (final e in expenses) {
      expenseCatMap[e.category] = (expenseCatMap[e.category] ?? 0) + e.amount;
    }

    return MonthlySummary(
      sales: sales, expenses: expenses, attendance: attendance,
      autoWages: autoWages,
      totalProfit: totalProfit, totalRevenue: totalRevenue, totalKg: totalKg,
      totalExpenses: totalExpenses, attendanceWages: attendWages,
      autoWageTotal: autoWageTotal,
      netProfit: totalProfit - totalExpenses,
      dailyMap: dailyMap, productMap: productMap,
      buyerList: buyerMapI.values.toList()
          ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit)),
      expenseCatMap: expenseCatMap,
      workerWageByRole: autoWageByRole,
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
  final Map<String, double> workerWageByRole;
  final List<BuyerMonthSummary> buyerList;
  const MonthlySummary({
    required this.sales, required this.expenses,
    required this.attendance, required this.autoWages,
    required this.totalProfit, required this.totalRevenue, required this.totalKg,
    required this.totalExpenses, required this.attendanceWages,
    required this.autoWageTotal, required this.netProfit,
    required this.dailyMap, required this.productMap,
    required this.buyerList, required this.expenseCatMap,
    required this.workerWageByRole,
  });
}