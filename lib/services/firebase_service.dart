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

  Future<void> updateRawMaterialTransaction(String id, Map<String, dynamic> fields) async {
  await _col('rawMaterialTransactions').doc(id).update(fields);
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
  // SALES
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> addSale(Sale sale) async {
    final ref = await _col('sales').add(sale.toMap());
    return ref.id;
  }

  Future<void> updateSaleRawMaterialCredit(String saleId, String creditId) {
    return _col('sales').doc(saleId).update({'rawMaterialCreditId': creditId});
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

  // Inclusive date-range query, used by the Filter tab. Both [start] and
  // [end] are calendar dates (time-of-day is ignored).
  Future<List<Sale>> salesForDateRange(DateTime start, DateTime end) async {
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final q = await _col('sales')
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .get();
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
  // BUYERS
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
  // BUYER TRANSACTIONS (simple)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<SimpleTransaction>> getBuyerSimpleTransactions(String buyerId) async {
    final q = await _col('simpleTransactions').where('buyerId', isEqualTo: buyerId).get();
    return q.docs.map((d) => SimpleTransaction.fromMap(d.id, d.data())).toList();
  }

  Stream<List<SimpleTransaction>> allBuyerSimpleTransactionsStream() =>
      _col('simpleTransactions').snapshots().map((s) => s.docs.map((d) => SimpleTransaction.fromMap(d.id, d.data())).toList());

  Future<String> addSimpleTransaction(SimpleTransaction tx) async {
    final ref = await _col('simpleTransactions').add(tx.toMap());
    return ref.id;
  }

  Future<void> deleteSimpleTransaction(String id) async => await _col('simpleTransactions').doc(id).delete();
  Future<void> updateSimpleTransaction(String id, {required double amount, required String note}) async =>
      await _col('simpleTransactions').doc(id).update({'amount': amount, 'note': note});

  // ══════════════════════════════════════════════════════════════════════════
  // WORKERS
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
  // EXPENSES
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

  // NOTE: [partyType] should be passed explicitly by the caller as 'buyer' or
  // 'supplier' — the caller already knows this from the dropdown selection
  // they showed the user. We no longer try to *guess* the type from the ID
  // string (buyer/supplier IDs are normal Firestore auto-IDs and never carry
  // a 'buyer_' prefix, so that old guess was always wrong in practice and
  // every party purchase was being mis-recorded as a 'supplier').
  Future<String> addRawMaterialTransaction(RawMaterialTransaction tx, {String? partyType}) async {
    final ref = await _col('rawMaterialTransactions').add(tx.toMap());
    // If supplierId is not null, update party stock (buyer or supplier)
    if (tx.supplierId != null && tx.transactionType == 'purchase') {
      final resolvedType = partyType ?? 'supplier';
      await updatePartyStock(
        tx.supplierId!,
        tx.supplierName ?? '',
        resolvedType,
        tx.materialType,
        tx.quantityKg, // positive for purchase
      );
    }
    return ref.id;
  }

  /// Deletes a raw-material transaction AND undoes everything it did.
  ///
  /// Company stock needs no repair — getCurrentStock() re-adds the remaining
  /// transactions every time, so removing the row removes its effect.
  ///
  /// Party stock is different: it is a running balance written at save time,
  /// so it must be reversed here or the party keeps kg they no longer gave us.
  ///
  /// Wastage rows written by the Sheet/Wastage screen also carry a pattarai
  /// ledger entry; that is removed too, otherwise the scrap store would still
  /// count material that has just been put back into stock.
  Future<void> deleteRawMaterialTransaction(String id) async {
    final doc = await _col('rawMaterialTransactions').doc(id).get();

    if (doc.exists) {
      final tx = RawMaterialTransaction.fromMap(doc.id, doc.data()!);

      // 1. Give back / take back the party's sheet balance.
      if (tx.supplierId != null && tx.supplierId!.isNotEmpty) {
        final party = await getPartyStock(tx.supplierId!);
        await updatePartyStock(
          tx.supplierId!,
          tx.supplierName ?? party?.partyName ?? '',
          party?.partyType ?? 'supplier',
          tx.materialType,
          partyStockReversalKg(tx),
        );
      }

      // 2. Drop the matching pattarai wastage entry, if this row came from one.
      if (tx.transactionType == 'wastage') {
        final linked = await _col('pattaraiStock')
            .where('stockTxId', isEqualTo: id)
            .get();
        for (final d in linked.docs) {
          await d.reference.delete();
        }
      }
    }

    await _col('rawMaterialTransactions').doc(id).delete();
  }

  /// What deleting [tx] will change — used to spell it out in the confirm
  /// dialog before anything is touched.
  Future<List<String>> describeDeleteEffects(RawMaterialTransaction tx) async {
    final kg = tx.quantityKg.abs().toStringAsFixed(2);
    final name = tx.materialType.displayName;
    final effects = <String>[];

    final isParty = tx.supplierId != null && tx.supplierId!.isNotEmpty;

    if (!isParty) {
      if (tx.transactionType == 'purchase') {
        effects.add('$kg kg $name comes OFF company stock');
      } else {
        effects.add('$kg kg $name goes BACK INTO company stock');
      }
    } else {
      final party = await getPartyStock(tx.supplierId!);
      final partyName =
          tx.supplierName ?? party?.partyName ?? 'the party';
      final current = party?.stock[tx.materialType] ?? 0;
      final after = current + partyStockReversalKg(tx);
      effects.add(
        '$partyName balance: ${current.toStringAsFixed(2)} kg → '
        '${after.toStringAsFixed(2)} kg $name',
      );
      if (after < -0.01) {
        effects.add('That leaves $partyName negative — they would owe sheet.');
      }
    }

    if (tx.transactionType == 'wastage') {
      effects.add('The matching wastage entry is removed from the pattarai '
          'ledger and the scrap store');
    }
    if (tx.isCredit && tx.creditAmount > 0) {
      effects.add('Note: the credit of Rs ${tx.creditAmount.round()} is NOT '
          'adjusted automatically — check the party account');
    }
    return effects;
  }

  Future<double> yearlyTotalProfit(int year) async {
    double total = 0;
    for (int month = 1; month <= 12; month++) {
      total += await monthlyTotalProfit(year, month);
    }
    return total;
  }

  Future<double> overallTotalProfit() async {
    final allSales = await getAllSales();
    double total = 0;
    for (final sale in allSales) {
      total += sale.profit;
    }
    return total;
  }

  // Get GLOBAL stock: sum transactions where supplierId == null.
  //
  // Transaction storage conventions:
  //   purchase     → quantityKg is POSITIVE  (adds to stock)
  //   consumption  → quantityKg is NEGATIVE  (already the right sign, stored
  //                  as -remainingKg in _save()). We just add it directly.
  //   sale         → quantityKg is POSITIVE  (we subtract it here)
  //
  // Rule: for 'purchase' add the value; for everything else subtract it.
  // But because consumption is already stored with a negative sign, we must
  // NOT double-negate it — so we detect 'consumption' explicitly and add it
  // directly (i.e. add a negative number = subtract).
  Future<Map<RawMaterialType, double>> getCurrentStock() async {
    final q = await _col('rawMaterialTransactions').get();
    Map<RawMaterialType, double> stock = {};
    for (var doc in q.docs) {
      final tx = RawMaterialTransaction.fromMap(doc.id, doc.data());
      // Only count transactions that are not linked to a party (global/company).
      // The sign rule lives in companyStockDelta() so it can be tested.
      if (affectsCompanyStock(tx)) {
        stock[tx.materialType] =
            (stock[tx.materialType] ?? 0) + companyStockDelta(tx);
      }
    }
    return stock;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PATTARAI STOCK — sheet issued to a workshop, pieces back, wastage.
  // See the accounting rules on PattaraiStockTx in models.dart.
  // ══════════════════════════════════════════════════════════════════════════

  Stream<List<PattaraiStockTx>> pattaraiStockStream() =>
      _col('pattaraiStock').snapshots().map((s) {
        final list = s.docs
            .map((d) => PattaraiStockTx.fromMap(d.id, d.data()))
            .toList();
        list.sort((a, b) => b.date.compareTo(a.date));
        return list;
      });

  Future<List<PattaraiStockTx>> getPattaraiStockTxs() async {
    final q = await _col('pattaraiStock').get();
    final list =
        q.docs.map((d) => PattaraiStockTx.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Records one pattarai entry.
  ///
  /// Wastage — and only wastage — also writes a company raw-material
  /// transaction so the loss comes off total stock. Issue and pieces are
  /// internal movements and leave company stock alone.
  Future<String> addPattaraiStockTx(PattaraiStockTx tx) async {
    String? stockTxId;

    if (tx.type == PattaraiTxType.wastage) {
      // supplierId stays null so getCurrentStock() counts it as company stock,
      // where any non-purchase type is subtracted.
      final ref = await _col('rawMaterialTransactions').add(
        RawMaterialTransaction(
          materialType: tx.materialType,
          date: tx.date,
          quantityKg: tx.quantityKg.abs(),
          ratePerKg: 0,
          transactionType: 'wastage',
          note: 'Wastage — ${tx.pattaraiName}'
              '${tx.note.isEmpty ? '' : ' (${tx.note})'}',
        ).toMap(),
      );
      stockTxId = ref.id;
    }

    final doc = await _col('pattaraiStock').add(
      PattaraiStockTx(
        pattaraiId: tx.pattaraiId,
        pattaraiName: tx.pattaraiName,
        type: tx.type,
        materialType: tx.materialType,
        quantityKg: tx.quantityKg.abs(),
        date: tx.date,
        note: tx.note,
        stockTxId: stockTxId,
      ).toMap(),
    );
    return doc.id;
  }

  /// Removes an entry, and for wastage puts the material back on company stock
  /// by deleting the linked transaction.
  Future<void> deletePattaraiStockTx(PattaraiStockTx tx) async {
    if (tx.stockTxId != null) {
      await _col('rawMaterialTransactions').doc(tx.stockTxId).delete();
    }
    if (tx.id != null) {
      await _col('pattaraiStock').doc(tx.id).delete();
    }
  }

  // ── Wastage sales (scrap sold off every few months) ───────────────────────
  // These never touch company sheet stock: the material already left stock the
  // moment the wastage was recorded. They only clear the scrap balance.

  Future<List<WastageSale>> getWastageSales() async {
    final q = await _col('wastageSales').get();
    final list =
        q.docs.map((d) => WastageSale.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<String> addWastageSale(WastageSale sale) async {
    final ref = await _col('wastageSales').add(sale.toMap());
    return ref.id;
  }

  Future<void> deleteWastageSale(String id) async =>
      await _col('wastageSales').doc(id).delete();

  // Get stock for a specific buyer (from partyStock)
  Future<double> getBuyerStock(String buyerId, RawMaterialType material) async {
    final party = await getPartyStock(buyerId);
    if (party == null) return 0.0;
    return party.stock[material] ?? 0.0;
  }

  // PARTY STOCK (for buyers/suppliers)
  // IMPORTANT: balances are allowed to go negative (negative = buyer owes
  // sheet / company over-issued). We must NOT remove the entry just because
  // it hits zero or goes negative, otherwise the debt record is lost and the
  // next sale silently treats this party as having a fresh 0 balance.
  // We only drop the key if it becomes *exactly* 0 to keep documents tidy;
  // any non-zero value (positive OR negative) is always stored.
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
    // Use a tiny epsilon so floating point noise doesn't leave a stray
    // 0.0000001 entry around forever, but real negative balances persist.
    if (newQty.abs() < 0.0001) {
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

  // ══════════════════════════════════════════════════════════════════════════
  // PATTARAI (shop / label name — display only)
  // ══════════════════════════════════════════════════════════════════════════
  Stream<List<Pattarai>> pattaraisStream() => _col('pattarais').snapshots().map((s) {
    final list = s.docs.map((d) => Pattarai.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  });

  Future<List<Pattarai>> getPattarais() async {
    final q = await _col('pattarais').get();
    final list = q.docs.map((d) => Pattarai.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  Future<void> savePattarai(Pattarai p) async {
    if (p.id == null) {
      final existing = await getPattarais();
      final isFirst = existing.isEmpty;
      await _col('pattarais').add(Pattarai(
        name: p.name,
        isActive: isFirst, // first one added becomes active automatically
        sortOrder: existing.length,
      ).toMap());
    } else {
      await _col('pattarais').doc(p.id).set(p.toMap());
    }
  }

  Future<void> deletePattarai(String id) => _col('pattarais').doc(id).delete();

  // Marks [id] as the active Pattarai and unsets all others.
  Future<void> setActivePattarai(String id) async {
    final all = await getPattarais();
    for (final p in all) {
      if (p.id == null) continue;
      final shouldBeActive = p.id == id;
      if (p.isActive != shouldBeActive) {
        await _col('pattarais').doc(p.id).update({'isActive': shouldBeActive});
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP SETTINGS (single document: settings/app)
  // ══════════════════════════════════════════════════════════════════════════
  Future<AppSettings> getAppSettings() async {
    final doc = await _col('settings').doc('app').get();
    if (doc.exists) return AppSettings.fromMap(doc.data()!);
    return const AppSettings();
  }

  Future<void> saveAppSettings(AppSettings settings) =>
      _col('settings').doc('app').set(settings.toMap());

  // Inside FirebaseService class

// Get total stock = global (company) stock + all party stocks.
//
// IMPORTANT BUSINESS RULE: a party's balance going negative just means that
// party "owes" sheet — the shortfall has already been pulled out of company
// stock at the time of sale, so a negative party balance must NOT be
// subtracted again here. Only POSITIVE party balances add to the displayed
// total; negative ones are ignored for this total (but are still visible to
// the user on the Parties tab as a debt indicator). The company/global
// stock itself IS allowed to go negative and is shown as-is.
Future<Map<RawMaterialType, double>> getTotalStock() async {
  // 1. Get global (company) stock — can be negative, shown as-is.
  final global = await getCurrentStock();

  // 2. Add what the parties hold. The positive-only rule lives in
  //    combineTotalStock() so it can be tested without Firestore.
  final partyDocs = await _col('partyStock').get();
  final parties =
      partyDocs.docs.map((d) => PartyStock.fromMap(d.id, d.data()));
  return combineTotalStock(global, parties);
}

// Update getCurrentStockForMaterial to use total if needed, but we'll keep it as global-only
// Keep the existing getCurrentStockForMaterial() as-is (for sales checks)

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
  // RANGE FILTER SUMMARY (for Monthly screen → Filter tab)
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Lets the user pick any start/end date and optionally narrow down by
  // buyer and/or material category (SS / Brass / Copper). Returns one
  // RangeSummary with totals, per-category breakdown, per-buyer breakdown,
  // and a day-by-day map (for the chart).
  Future<RangeSummary> rangeSummary({
    required DateTime start,
    required DateTime end,
    String? buyerId,
    String? category, // 'SS' | 'Brass' | 'Copper' | null for all
  }) async {
    final allSales = await salesForDateRange(start, end);

    final sales = allSales.where((s) {
      if (buyerId != null && buyerId.isNotEmpty && s.buyerId != buyerId) return false;
      if (category != null && category.isNotEmpty && s.productCategory != category) return false;
      return true;
    }).toList();

    double totalProfit = 0, totalRevenue = 0, totalKg = 0;
    final Map<String, double> profitByCategory = {};
    final Map<String, double> kgByCategory = {};
    final Map<String, double> revenueByCategory = {};
    final Map<String, RangeBuyerStat> byBuyer = {};
    final Map<String, double> dailyProfitMap = {};
    final Map<String, double> dailyKgMap = {};

    for (final s in sales) {
      totalProfit += s.profit;
      totalRevenue += s.qty * s.salePrice;
      totalKg += s.qty;

      final cat = s.productCategory;
      profitByCategory[cat] = (profitByCategory[cat] ?? 0) + s.profit;
      kgByCategory[cat] = (kgByCategory[cat] ?? 0) + s.qty;
      revenueByCategory[cat] = (revenueByCategory[cat] ?? 0) + (s.qty * s.salePrice);

      if (s.buyerId != null && s.buyerId!.isNotEmpty) {
        byBuyer.putIfAbsent(s.buyerId!,
            () => RangeBuyerStat(buyerId: s.buyerId!, buyerName: s.buyerName ?? 'Unknown'));
        byBuyer[s.buyerId!]!.add(s);
      }

      final dk = s.date.toIso8601String().substring(0, 10);
      dailyProfitMap[dk] = (dailyProfitMap[dk] ?? 0) + s.profit;
      dailyKgMap[dk] = (dailyKgMap[dk] ?? 0) + s.qty;
    }

    final buyerList = byBuyer.values.toList()
      ..sort((a, b) => b.totalProfit.compareTo(a.totalProfit));

    return RangeSummary(
      start: start,
      end: end,
      sales: sales,
      totalProfit: totalProfit,
      totalRevenue: totalRevenue,
      totalKg: totalKg,
      profitByCategory: profitByCategory,
      kgByCategory: kgByCategory,
      revenueByCategory: revenueByCategory,
      buyerList: buyerList,
      dailyProfitMap: dailyProfitMap,
      dailyKgMap: dailyKgMap,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MONTHLY SUMMARY
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

    // Category breakdown
    final Map<String, double> profitByCategory = {};
    final Map<String, double> kgByCategory = {};

    for (final s in sales) {
      final dk = s.date.toIso8601String().substring(0,10);
      dailyMap[dk] = (dailyMap[dk] ?? 0) + s.profit;
      final pk = '${s.productId}|${s.productName}';
      productMap[pk] = (productMap[pk] ?? 0) + s.profit;
      if (s.buyerId != null && s.buyerId!.isNotEmpty) {
        buyerMapI[s.buyerId!] ??= BuyerMonthSummary(buyerId: s.buyerId!, buyerName: s.buyerName ?? 'Unknown');
        buyerMapI[s.buyerId!]!.add(s);
      }

      // Category totals
      final cat = s.productCategory;
      profitByCategory[cat] = (profitByCategory[cat] ?? 0) + s.profit;
      kgByCategory[cat] = (kgByCategory[cat] ?? 0) + s.qty;
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
      profitByCategory: profitByCategory,
      kgByCategory: kgByCategory,
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

  // ══════════════════════════════════════════════════════════════════════════
  // EDIT SALE — full field update (qty, price, buyer, raw-material rate).
  // Does NOT touch stock/credit side-effects; the home screen handles those
  // (reverse the old sale's effects, then apply the new ones) before calling
  // this, the same way _deleteSale already reverses effects before deleting.
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> updateSale(String saleId, Map<String, dynamic> fields) async {
    await _col('sales').doc(saleId).update(fields);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUSINESS PROFILE (PAN / GST / address / bank / UPI+QR) — single doc,
  // same pattern as APP SETTINGS above.
  // ══════════════════════════════════════════════════════════════════════════
  Future<BusinessProfile> getBusinessProfile() async {
    final doc = await _col('settings').doc('business').get();
    if (doc.exists) return BusinessProfile.fromMap(doc.data()!);
    return const BusinessProfile();
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) =>
      _col('settings').doc('business').set(profile.toMap());
}

// Supporting data classes (unchanged)
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

// Same shape as BuyerMonthSummary, used by the date-range Filter tab.
class RangeBuyerStat {
  final String buyerId, buyerName;
  int salesCount = 0;
  double totalKg = 0, totalRevenue = 0, totalProfit = 0;
  RangeBuyerStat({required this.buyerId, required this.buyerName});
  void add(Sale s) {
    salesCount++;
    totalKg += s.qty;
    totalRevenue += s.qty * s.salePrice;
    totalProfit += s.profit;
  }
}

// Result of FirebaseService.rangeSummary() — everything the Filter tab needs.
class RangeSummary {
  final DateTime start, end;
  final List<Sale> sales;
  final double totalProfit, totalRevenue, totalKg;
  final Map<String, double> profitByCategory;
  final Map<String, double> kgByCategory;
  final Map<String, double> revenueByCategory;
  final List<RangeBuyerStat> buyerList;
  final Map<String, double> dailyProfitMap;
  final Map<String, double> dailyKgMap;

  const RangeSummary({
    required this.start,
    required this.end,
    required this.sales,
    required this.totalProfit,
    required this.totalRevenue,
    required this.totalKg,
    required this.profitByCategory,
    required this.kgByCategory,
    required this.revenueByCategory,
    required this.buyerList,
    required this.dailyProfitMap,
    required this.dailyKgMap,
  });

  int get daysInRange => end.difference(start).inDays + 1;
  double get avgProfitPerDay => daysInRange > 0 ? totalProfit / daysInRange : 0;
  double get avgKgPerDay => daysInRange > 0 ? totalKg / daysInRange : 0;
  int get salesCount => sales.length;
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
  final Map<String, double> profitByCategory;
  final Map<String, double> kgByCategory;

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
    required this.profitByCategory,
    required this.kgByCategory,
  });
}