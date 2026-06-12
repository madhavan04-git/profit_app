// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  String get uid => _auth.currentUser!.uid;

  static const String _validRegistrationKey = 'Mathavan@367';

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(uid).collection(name);

  // ══════════════════════════════════════════════════════════════════════════
  // AUTH (unchanged)
  // ══════════════════════════════════════════════════════════════════════════

  Future<UserCredential> register(String email, String password, String name, String registrationKey) async {
    if (registrationKey != _validRegistrationKey) throw Exception('invalid-registration-key');
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await cred.user!.updateDisplayName(name);
    await _db.collection('users').doc(cred.user!.uid).set({
      'name': name, 'email': email, 'target': 30000, 'createdAt': FieldValue.serverTimestamp(),
    });
    await _seedProducts(cred.user!.uid);
    return cred;
  }

  Future<UserCredential> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _ensureSeeded(cred.user!.uid);
    return cred;
  }

  Future<void> logout() => _auth.signOut();
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureSeeded(String uid) async {
    final snap = await _db.collection('users').doc(uid).collection('products').limit(1).get();
    if (snap.docs.isEmpty) await _seedProducts(uid);
  }

  Future<void> _seedProducts(String uid) async {
    final col = _db.collection('users').doc(uid).collection('products');
    final batch = _db.batch();
    for (final p in _defaultProducts) batch.set(col.doc(), p.toMap());
    await batch.commit();
  }

  static final _defaultProducts = [
    Product(name:'SS-I (1½ padii)', category:'SS', padii:'1½ padii',
        productWeightG:500, sellPricePerKg:230,
        costLabour1:7, costPlasma1:12.5, costWelding1:4, costRunner1:8,
        costVarai:8, costPolish1:44),
    Product(name:'SS-II (1 padii)', category:'SS', padii:'1 padii',
        productWeightG:300, sellPricePerKg:230,
        costLabour1:3.5, costPlasma1:6.5, costWelding1:2, costRunner1:4,
        costVarai:4, costPolish1:23),
    Product(name:'SS-III (½ padii)', category:'SS', padii:'½ padii',
        productWeightG:300, sellPricePerKg:230,
        costLabour1:3.5, costPlasma1:6.5, costWelding1:2, costRunner1:4,
        costVarai:4, costPolish1:23),
    Product(name:'SS-IV (¼ piece)', category:'SS', padii:'¼ piece',
        productWeightG:100, sellPricePerKg:800,
        soldByPiece:true, unit:'pcs',
        costMaterial:17, costLabour1:3.5, costPlasma1:6.5,
        costWelding1:2, costRunner1:4, costVarai:4, costPolish1:23),
    Product(name:'BR-II (1½ padii)', category:'Brass', padii:'1½ padii',
        productWeightG:700, sellPricePerKg:350,
        costLabour1:10, costVettu1:7, costWelding1:10,
        costRunner1:10, costVarai:10, costPolish1:58),
    Product(name:'BR-III (1½+¼ padii)', category:'Brass', padii:'1½+¼ padii',
        productWeightG:900, sellPricePerKg:350,
        costLabour1:10, costVettu1:8, costWelding1:18,
        costRunner1:15, costVarai:15, costPolish1:82),
    Product(name:'BR-IV (¼ kg)', category:'Brass', padii:'¼ kg',
        productWeightG:200, sellPricePerKg:350,
        costLabour1:5, costVettu1:2, costWelding1:7,
        costRunner1:5, costVarai:5, costPolish1:24),
    Product(name:'BR-V (1 kg)', category:'Brass', padii:'1 kg',
        productWeightG:400, sellPricePerKg:350,
        costLabour1:5, costVettu1:5, costWelding1:9,
        costRunner1:5, costVarai:5, costPolish1:31),
    Product(name:'BR-VI (½ kg)', category:'Brass', padii:'½ kg',
        productWeightG:300, sellPricePerKg:350,
        costLabour1:5, costVettu1:5, costWelding1:8,
        costRunner1:5, costVarai:5, costPolish1:27),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS (unchanged)
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
    if (p.id == null) await _col('products').add(p.toMap());
    else await _col('products').doc(p.id).set(p.toMap());
  }

  Future<void> deactivateProduct(String id) => _col('products').doc(id).update({'isActive': false});

  // ══════════════════════════════════════════════════════════════════════════
  // SALES (addSale includes stock deduction)
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> addSale(Sale sale) async {
    final ref = await _col('sales').add(sale.toMap());
    // Deduct raw material stock from buyer if the buyer exists and has stock
    if (sale.buyerId != null && sale.buyerId!.isNotEmpty) {
      final partyStock = await getPartyStock(sale.buyerId!);
      if (partyStock != null && partyStock.stock.isNotEmpty) {
        // For simplicity, deduct from the first available material
        final material = partyStock.stock.keys.first;
        final currentQty = partyStock.stock[material]!;
        final newQty = currentQty - sale.qty;
        if (newQty <= 0) {
          partyStock.stock.remove(material);
        } else {
          partyStock.stock[material] = newQty;
        }
        await _col('partyStock').doc(sale.buyerId).set(partyStock.toMap());
      }
    }
    return ref.id;
  }

  Future<void> deleteSale(String id) => _col('sales').doc(id).delete();

  Future<List<Sale>> salesForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final q = await _col('sales').where('date', isEqualTo: dateStr).get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.millisecondsSinceEpoch.compareTo(a.date.millisecondsSinceEpoch));
    return list;
  }

  Future<List<Sale>> salesForMonth(int year, int month) async {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final q = await _col('sales')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo: '$y-$m-31').get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  Future<double> monthlyTotalProfit(int year, int month) async {
    final sales = await salesForMonth(year, month);
    return sales.fold<double>(0.0, (sum, s) => sum + s.profit);
  }

  Future<List<Sale>> salesForBuyer(String buyerId) async {
    final q = await _col('sales').where('buyerId', isEqualTo: buyerId).get();
    final list = q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUYERS (unchanged)
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Buyer>> buyersStream() => _col('buyers').where('isActive', isEqualTo: true).snapshots().map((s) {
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

  Future<void> deleteBuyer(String id) => _col('buyers').doc(id).update({'isActive': false});

  // ══════════════════════════════════════════════════════════════════════════
  // BUYER TRANSACTIONS (simple) — unchanged
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<SimpleTransaction>> getBuyerSimpleTransactions(String buyerId) async {
    final q = await _col('simpleTransactions').where('buyerId', isEqualTo: buyerId).get();
    return q.docs.map((d) => SimpleTransaction.fromMap(d.id, d.data())).toList();
  }

  Stream<List<SimpleTransaction>> allBuyerSimpleTransactionsStream() =>
      _col('simpleTransactions').snapshots().map((s) => s.docs.map((d) => SimpleTransaction.fromMap(d.id, d.data())).toList());

  Future<void> addSimpleTransaction(SimpleTransaction tx) async => await _col('simpleTransactions').add(tx.toMap());
  Future<void> deleteSimpleTransaction(String id) async => await _col('simpleTransactions').doc(id).delete();
  Future<void> updateSimpleTransaction(String id, {required double amount, required String note}) async =>
      await _col('simpleTransactions').doc(id).update({'amount': amount, 'note': note});

  // ══════════════════════════════════════════════════════════════════════════
  // WORKERS (unchanged)
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<Worker>> workersStream() => _col('workers').where('isActive', isEqualTo: true).snapshots().map((s) {
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

  Future<void> deleteWorker(String id) => _col('workers').doc(id).update({'isActive': false});

  // WORKER SIMPLE TRANSACTIONS
  Future<List<WorkerSimpleTransaction>> getWorkerSimpleTransactions(String workerId) async {
    final q = await _col('workerSimpleTransactions').where('workerId', isEqualTo: workerId).get();
    return q.docs.map((d) => WorkerSimpleTransaction.fromMap(d.id, d.data())).toList();
  }

  Stream<List<WorkerSimpleTransaction>> allWorkerSimpleTransactionsStream() =>
      _col('workerSimpleTransactions').snapshots().map((s) => s.docs.map((d) => WorkerSimpleTransaction.fromMap(d.id, d.data())).toList());

  Future<void> addWorkerSimpleTransaction(WorkerSimpleTransaction tx) async =>
      await _col('workerSimpleTransactions').add(tx.toMap());
  Future<void> updateWorkerSimpleTransaction(String id, {required double amount, required String note}) async =>
      await _col('workerSimpleTransactions').doc(id).update({'amount': amount, 'note': note});
  Future<void> deleteWorkerSimpleTransaction(String id) async =>
      await _col('workerSimpleTransactions').doc(id).delete();

  // ATTENDANCE
  Future<void> saveAttendance(WorkerAttendance a) async {
    final dateStr = a.date.toIso8601String().substring(0,10);
    final q = await _col('attendance').where('workerId', isEqualTo: a.workerId).where('date', isEqualTo: dateStr).get();
    if (q.docs.isEmpty) await _col('attendance').add(a.toMap());
    else await _col('attendance').doc(q.docs.first.id).set(a.toMap());
  }

  Future<List<WorkerAttendance>> attendanceForDate(DateTime date) async {
    final dateStr = date.toIso8601String().substring(0,10);
    final q = await _col('attendance').where('date', isEqualTo: dateStr).get();
    return q.docs.map((d) => WorkerAttendance.fromMap(d.id, d.data())).toList();
  }

  Future<List<WorkerAttendance>> attendanceForMonth(int year, int month) async {
    final y = year.toString().padLeft(4,'0');
    final m = month.toString().padLeft(2,'0');
    final q = await _col('attendance')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo: '$y-$m-31').get();
    final list = q.docs.map((d) => WorkerAttendance.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPENSES (unchanged)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addExpense(Expense e) => _col('expenses').add(e.toMap());
  Future<void> deleteExpense(String id) => _col('expenses').doc(id).delete();

  Future<List<Expense>> expensesForMonth(int year, int month) async {
    final y = year.toString().padLeft(4,'0');
    final m = month.toString().padLeft(2,'0');
    final q = await _col('expenses')
        .where('date', isGreaterThanOrEqualTo: '$y-$m-01')
        .where('date', isLessThanOrEqualTo: '$y-$m-31').get();
    final list = q.docs.map((d) => Expense.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RAW MATERIAL TRACKING & PARTY STOCK
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<RawMaterialTransaction>> rawMaterialTransactionsStream() =>
      _col('rawMaterialTransactions').orderBy('timestamp', descending: true).snapshots()
          .map((s) => s.docs.map((d) => RawMaterialTransaction.fromMap(d.id, d.data())).toList());

Future<void> addRawMaterialTransaction(RawMaterialTransaction tx) async {
  await _col('rawMaterialTransactions').add(tx.toMap());
  // Update party stock if it's a purchase
  if (tx.supplierId != null && tx.transactionType == 'purchase') {
    await updatePartyStock(tx.supplierId!, tx.supplierName ?? '',
        tx.supplierId!.startsWith('buyer_') ? 'buyer' : 'supplier',
        tx.materialType, tx.quantityKg);
  }
}

  Future<void> deleteRawMaterialTransaction(String id) async {
    await _col('rawMaterialTransactions').doc(id).delete();
  }

  // Yearly total profit for a given year (sum of all 12 months)
Future<double> yearlyTotalProfit(int year) async {
  double total = 0;
  for (int month = 1; month <= 12; month++) {
    total += await monthlyTotalProfit(year, month);
  }
  return total;
}

// Overall profit from the very first sale
Future<double> overallTotalProfit() async {
  final allSales = await getAllSales();
  double total = 0;
  for (final sale in allSales) {
    total += sale.profit;
  }
  return total;
}

  Future<Map<RawMaterialType, double>> getCurrentStock() async {
    final q = await _col('rawMaterialTransactions').get();
    Map<RawMaterialType, double> stock = {};
    for (var doc in q.docs) {
      final tx = RawMaterialTransaction.fromMap(doc.id, doc.data());
      final delta = tx.transactionType == 'purchase' ? tx.quantityKg : -tx.quantityKg;
      stock[tx.materialType] = (stock[tx.materialType] ?? 0) + delta;
    }
    return stock;
  }

  // PARTY STOCK (for buyers/suppliers)
  Future<void> updatePartyStock(String partyId, String partyName, String partyType,
      RawMaterialType material, double changeKg) async {
    final docRef = _col('partyStock').doc(partyId);
    final doc = await docRef.get();
    Map<RawMaterialType, double> currentStock = {};
    if (doc.exists) {
      final p = PartyStock.fromMap(doc.id, doc.data()!);
      currentStock = p.stock;
    }
    final newQty = (currentStock[material] ?? 0) + changeKg;
    if (newQty <= 0) {
      currentStock.remove(material);
    } else {
      currentStock[material] = newQty;
    }
    await docRef.set(PartyStock(
      partyId: partyId,
      partyName: partyName,
      partyType: partyType,
      stock: currentStock,
    ).toMap());
  }

  Future<PartyStock?> getPartyStock(String partyId) async {
    final doc = await _col('partyStock').doc(partyId).get();
    if (doc.exists) return PartyStock.fromMap(doc.id, doc.data()!);
    return null;
  }

  // SUPPLIERS
  Stream<List<Supplier>> suppliersStream() =>
      _col('suppliers').where('isActive', isEqualTo: true).snapshots()
          .map((s) => s.docs.map((d) => Supplier.fromMap(d.id, d.data())).toList());

  Future<List<Supplier>> getSuppliers() async {
    final q = await _col('suppliers').where('isActive', isEqualTo: true).get();
    return q.docs.map((d) => Supplier.fromMap(d.id, d.data())).toList();
  }

  Future<void> saveSupplier(Supplier s) async {
    if (s.id == null) await _col('suppliers').add(s.toMap());
    else await _col('suppliers').doc(s.id).set(s.toMap());
  }

  

  // SUPPLIER CREDIT
  Stream<List<SupplierCredit>> supplierCreditStream() =>
      _col('supplierCredits').snapshots()
          .map((s) => s.docs.map((d) => SupplierCredit.fromMap(d.data())).toList());

  Future<void> updateSupplierCredit(String supplierId, String supplierName, double creditChange, double paymentChange) async {
    final docRef = _col('supplierCredits').doc(supplierId);
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      final newCredit = (data['totalCredit'] as num? ?? 0) + creditChange;
      final newPaid = (data['totalPaid'] as num? ?? 0) + paymentChange;
      await docRef.update({'totalCredit': newCredit, 'totalPaid': newPaid});
    } else {
      await docRef.set({
        'supplierId': supplierId,
        'supplierName': supplierName,
        'totalCredit': creditChange.clamp(0, double.infinity),
        'totalPaid': paymentChange.clamp(0, double.infinity),
      });
    }
  }

Future<List<PartyStock>> getAllPartyStock() async {
  final q = await _col('partyStock').get();
  return q.docs.map((doc) => PartyStock.fromMap(doc.id, doc.data())).toList();
}

Future<double> getCurrentStockForMaterial(RawMaterialType material) async {
  final stock = await getCurrentStock();
  return stock[material] ?? 0.0;
}


  // MONTHLY MATERIAL SUMMARY
  Future<Map<String, Map<String, double>>> monthlyMaterialSummary(int year, int month) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final q = await _col('rawMaterialTransactions')
        .where('timestamp', isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
        .where('timestamp', isLessThanOrEqualTo: end.millisecondsSinceEpoch)
        .get();
    Map<String, Map<String, double>> result = {};
    for (var doc in q.docs) {
      final tx = RawMaterialTransaction.fromMap(doc.id, doc.data());
      final key = tx.materialType.displayName;
      result.putIfAbsent(key, () => {'purchase': 0, 'sale': 0});
      if (tx.transactionType == 'purchase') {
        result[key]!['purchase'] = (result[key]!['purchase'] ?? 0) + tx.quantityKg;
      } else {
        result[key]!['sale'] = (result[key]!['sale'] ?? 0) + tx.quantityKg;
      }
    }
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MONTHLY SUMMARY (unchanged)
  // ══════════════════════════════════════════════════════════════════════════

  Future<MonthlySummary> monthlySummary(int year, int month) async {
    final results = await Future.wait([
      salesForMonth(year, month),
      expensesForMonth(year, month),
      attendanceForMonth(year, month),
      getWorkers(),
    ]);
    final sales = results[0] as List<Sale>;
    final expenses = results[1] as List<Expense>;
    final attendance = results[2] as List<WorkerAttendance>;
    final workers = results[3] as List<Worker>;

    final totalProfit = sales.fold(0.0, (s, x) => s + x.profit);
    final totalRevenue = sales.fold(0.0, (s, x) => s + x.qty * x.salePrice);
    final totalKg = sales.fold(0.0, (s, x) => s + x.qty);
    final totalExpenses = expenses.fold(0.0, (s, x) => s + x.amount);
    final attendWages = attendance.where((a) => a.present).fold(0.0, (s, a) => s + a.wage);

    final Map<String, double> autoWageByRole = {};
    for (final sale in sales) {
      sale.workerRatesPerKg.forEach((role, ratePerKg) {
        autoWageByRole[role] = (autoWageByRole[role] ?? 0) + ratePerKg * sale.qty;
      });
    }

    final List<WorkerAutoWage> autoWages = [];
    final Set<String> matchedRoles = {};
    for (final w in workers) {
      final wage = autoWageByRole[w.role] ?? 0;
      if (wage > 0) {
        matchedRoles.add(w.role);
        autoWages.add(WorkerAutoWage(worker: w, totalKg: totalKg, ratePerKg: 0, autoWage: wage));
      }
    }
    autoWageByRole.forEach((role, wage) {
      if (!matchedRoles.contains(role)) {
        autoWages.add(WorkerAutoWage(worker: Worker(name: role, role: role, dailyWage: 0), totalKg: totalKg, ratePerKg: 0, autoWage: wage));
      }
    });
    final autoWageTotal = autoWageByRole.values.fold(0.0, (s, v) => s + v);

    final Map<String, double> dailyMap = {};
    final Map<String, double> productMap = {};
    final Map<String, BuyerMonthSummary> buyerMapI = {};
    final Map<String, double> expenseCatMap = {};

    for (final s in sales) {
      final dk = s.date.toIso8601String().substring(0,10);
      dailyMap[dk] = (dailyMap[dk] ?? 0) + s.profit;
      final pk = '${s.productId}|${s.productName}';
      productMap[pk] = (productMap[pk] ?? 0) + s.profit;
      if (s.buyerId != null && s.buyerId!.isNotEmpty) {
        buyerMapI[s.buyerId!] ??= BuyerMonthSummary(buyerId: s.buyerId!, buyerName: s.buyerName ?? 'Unknown');
        buyerMapI[s.buyerId!]!.add(s);
      }
    }
    for (final e in expenses) {
      expenseCatMap[e.category] = (expenseCatMap[e.category] ?? 0) + e.amount;
    }

    return MonthlySummary(
      sales: sales,
      expenses: expenses,
      attendance: attendance,
      autoWages: autoWages,
      totalProfit: totalProfit,
      totalRevenue: totalRevenue,
      totalKg: totalKg,
      totalExpenses: totalExpenses,
      attendanceWages: attendWages,
      autoWageTotal: autoWageTotal,
      netProfit: totalProfit - totalExpenses,
      dailyMap: dailyMap,
      productMap: productMap,
      buyerList: buyerMapI.values.toList()..sort((a, b) => b.totalProfit.compareTo(a.totalProfit)),
      expenseCatMap: expenseCatMap,
      workerWageByRole: autoWageByRole,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GET ALL SALES
  // ══════════════════════════════════════════════════════════════════════════
  Future<List<Sale>> getAllSales() async {
    final q = await _col('sales').get();
    return q.docs.map((d) => Sale.fromMap(d.id, d.data())).toList();
  }

  // Helper for worker earnings update
  Future<void> updateSaleEarnings(String saleId, String workerRole, double newQty, double newRate) async {
    final saleRef = _col('sales').doc(saleId);
    await _db.runTransaction((transaction) async {
      final saleDoc = await transaction.get(saleRef);
      if (saleDoc.exists) {
        final saleData = saleDoc.data() as Map<String, dynamic>;
        final currentRates = Map<String, dynamic>.from(saleData['workerRatesPerKg'] ?? {});
        currentRates[workerRole] = newRate;
        transaction.update(saleRef, {'qty': newQty, 'workerRatesPerKg': currentRates});
      }
    });
  }

  Future<void> updateSalePrice(String saleId, double newPrice) async {
    final saleRef = _col('sales').doc(saleId);
    await _db.runTransaction((transaction) async {
      final saleDoc = await transaction.get(saleRef);
      if (saleDoc.exists) {
        transaction.update(saleRef, {'salePrice': newPrice});
      }
    });
  }
}

// Add anywhere inside the FirebaseService class, for example after getCurrentStock():



// Supporting data classes
class BuyerMonthSummary {
  final String buyerId, buyerName;
  int salesCount = 0;
  double totalKg = 0, totalRevenue = 0, totalProfit = 0;
  BuyerMonthSummary({required this.buyerId, required this.buyerName});
  void add(Sale s) {
    salesCount++;
    totalKg += s.qty;
    totalRevenue += s.qty * s.salePrice;
    totalProfit += s.profit;
  }
}

class WorkerAutoWage {
  final Worker worker;
  final double totalKg, ratePerKg, autoWage;
  const WorkerAutoWage({required this.worker, required this.totalKg, required this.ratePerKg, required this.autoWage});
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
    required this.sales,
    required this.expenses,
    required this.attendance,
    required this.autoWages,
    required this.totalProfit,
    required this.totalRevenue,
    required this.totalKg,
    required this.totalExpenses,
    required this.attendanceWages,
    required this.autoWageTotal,
    required this.netProfit,
    required this.dailyMap,
    required this.productMap,
    required this.buyerList,
    required this.expenseCatMap,
    required this.workerWageByRole,
  });
}


