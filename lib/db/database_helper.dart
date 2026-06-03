// lib/db/database_helper.dart
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/product.dart';
import '../models/sale.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _db;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('profit_tracker.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);
    return await openDatabase(path, version: 4,
        onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        name              TEXT NOT NULL,
        category          TEXT NOT NULL,
        padii             TEXT,
        product_weight_g  INTEGER NOT NULL,
        sell_price_per_kg REAL NOT NULL,
        sold_by_piece     INTEGER NOT NULL DEFAULT 0,
        unit              TEXT NOT NULL DEFAULT 'kg',
        cost_labour       REAL DEFAULT 0,
        cost_plasma       REAL DEFAULT 0,
        cost_vettu        REAL DEFAULT 0,
        cost_welding      REAL DEFAULT 0,
        cost_runner       REAL DEFAULT 0,
        cost_varai        REAL DEFAULT 0,
        cost_polish       REAL DEFAULT 0,
        cost_material     REAL DEFAULT 0,
        is_active         INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE sales (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id        INTEGER NOT NULL,
        product_name      TEXT NOT NULL,
        product_category  TEXT NOT NULL,
        qty               REAL NOT NULL,
        date              TEXT NOT NULL,
        profit            REAL NOT NULL
      )
    ''');
    await _insertDefaultProducts(db);
  }

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        padii TEXT,
        product_weight_g INTEGER NOT NULL,
        sell_price_per_kg REAL NOT NULL,
        sold_by_piece INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'kg',
        cost_labour REAL DEFAULT 0,
        cost_plasma REAL DEFAULT 0,
        cost_vettu REAL DEFAULT 0,
        cost_welding REAL DEFAULT 0,
        cost_runner REAL DEFAULT 0,
        cost_varai REAL DEFAULT 0,
        cost_polish REAL DEFAULT 0,
        cost_material REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1
      )
    ''');

    await _insertDefaultProducts(db);
  }
}

  // ── Default products seeded on first install ────────────────────────────
  Future<void> _insertDefaultProducts(Database db) async {
    final defaults = [
      {'name':'SS-I (1½ padii)','category':'SS','padii':'1½ padii','product_weight_g':500,'sell_price_per_kg':230.0,'sold_by_piece':0,'unit':'kg','cost_labour':7.0,'cost_plasma':12.5,'cost_vettu':0.0,'cost_welding':4.0,'cost_runner':8.0,'cost_varai':8.0,'cost_polish':44.0,'cost_material':0.0,'is_active':1},
      {'name':'SS-II (1 padii)','category':'SS','padii':'1 padii','product_weight_g':300,'sell_price_per_kg':230.0,'sold_by_piece':0,'unit':'kg','cost_labour':3.5,'cost_plasma':6.5,'cost_vettu':0.0,'cost_welding':2.0,'cost_runner':4.0,'cost_varai':4.0,'cost_polish':23.0,'cost_material':0.0,'is_active':1},
      {'name':'SS-III (½ padii)','category':'SS','padii':'½ padii','product_weight_g':300,'sell_price_per_kg':230.0,'sold_by_piece':0,'unit':'kg','cost_labour':3.5,'cost_plasma':6.5,'cost_vettu':0.0,'cost_welding':2.0,'cost_runner':4.0,'cost_varai':4.0,'cost_polish':23.0,'cost_material':0.0,'is_active':1},
      {'name':'SS-IV (¼ piece)','category':'SS','padii':'¼ piece','product_weight_g':100,'sell_price_per_kg':800.0,'sold_by_piece':1,'unit':'pcs','cost_labour':3.5,'cost_plasma':6.5,'cost_vettu':0.0,'cost_welding':2.0,'cost_runner':4.0,'cost_varai':4.0,'cost_polish':23.0,'cost_material':17.0,'is_active':1},
      {'name':'BR-II (1½ padii)','category':'Brass','padii':'1½ padii','product_weight_g':700,'sell_price_per_kg':350.0,'sold_by_piece':0,'unit':'kg','cost_labour':10.0,'cost_plasma':0.0,'cost_vettu':7.0,'cost_welding':10.0,'cost_runner':10.0,'cost_varai':10.0,'cost_polish':58.0,'cost_material':0.0,'is_active':1},
      {'name':'BR-III (1½+¼ padii)','category':'Brass','padii':'1½+¼ padii','product_weight_g':900,'sell_price_per_kg':350.0,'sold_by_piece':0,'unit':'kg','cost_labour':10.0,'cost_plasma':0.0,'cost_vettu':8.0,'cost_welding':18.0,'cost_runner':15.0,'cost_varai':15.0,'cost_polish':82.0,'cost_material':0.0,'is_active':1},
      {'name':'BR-IV (¼ kg)','category':'Brass','padii':'¼ kg','product_weight_g':200,'sell_price_per_kg':350.0,'sold_by_piece':0,'unit':'kg','cost_labour':5.0,'cost_plasma':0.0,'cost_vettu':2.0,'cost_welding':7.0,'cost_runner':5.0,'cost_varai':5.0,'cost_polish':24.0,'cost_material':0.0,'is_active':1},
      {'name':'BR-V (1 kg)','category':'Brass','padii':'1 kg','product_weight_g':400,'sell_price_per_kg':350.0,'sold_by_piece':0,'unit':'kg','cost_labour':5.0,'cost_plasma':0.0,'cost_vettu':5.0,'cost_welding':9.0,'cost_runner':5.0,'cost_varai':5.0,'cost_polish':31.0,'cost_material':0.0,'is_active':1},
      {'name':'BR-VI (½ kg)','category':'Brass','padii':'½ kg','product_weight_g':300,'sell_price_per_kg':350.0,'sold_by_piece':0,'unit':'kg','cost_labour':5.0,'cost_plasma':0.0,'cost_vettu':5.0,'cost_welding':8.0,'cost_runner':5.0,'cost_varai':5.0,'cost_polish':27.0,'cost_material':0.0,'is_active':1},
    ];
    for (final d in defaults) {
      await db.insert('products', d);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRODUCTS CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Product>> allProducts({bool activeOnly = true}) async {
    final db = await database;
    final maps = activeOnly
        ? await db.query('products', where: 'is_active = 1', orderBy: 'category, name')
        : await db.query('products', orderBy: 'category, name');
    return maps.map(Product.fromMap).toList();
  }

  Future<Product?> productById(int id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product> insertProduct(Product product) async {
    final db = await database;
    final map = product.toMap()..remove('id');
    final id = await db.insert('products', map);
    return product.copyWith(id: id);
  }

  Future<void> updateProduct(Product product) async {
    final db = await database;
    await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deactivateProduct(int id) async {
    final db = await database;
    await db.update('products', {'is_active': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<String>> allCategories() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT DISTINCT category FROM products ORDER BY category');
    return result.map((r) => r['category'] as String).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SALES CRUD
  // ══════════════════════════════════════════════════════════════════════════

  Future<Sale> insertSale(Sale sale) async {
    final db = await database;
    final id = await db.insert('sales', sale.toMap());
    return sale.copyWith(id: id);
  }

  Future<void> deleteSale(int id) async {
    final db = await database;
    await db.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Sale>> salesForDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final maps = await db.query('sales',
        where: 'date = ?', whereArgs: [dateStr], orderBy: 'id DESC');
    return maps.map(Sale.fromMap).toList();
  }

  Future<List<Sale>> salesForMonth(int year, int month) async {
    final db = await database;
    final prefix =
        '${year.toString().padLeft(4,'0')}-${month.toString().padLeft(2,'0')}';
    final maps = await db.query('sales',
        where: "date LIKE ?", whereArgs: ['$prefix%'], orderBy: 'date ASC');
    return maps.map(Sale.fromMap).toList();
  }

  Future<Map<String, double>> dailyProfitMap(int year, int month) async {
    final sales = await salesForMonth(year, month);
    final Map<String, double> map = {};
    for (final s in sales) {
      final key = s.date.toIso8601String().substring(0, 10);
      map[key] = (map[key] ?? 0) + s.profit;
    }
    return map;
  }

  Future<Map<String, double>> productProfitMap(int year, int month) async {
    final sales = await salesForMonth(year, month);
    final Map<String, double> map = {};
    for (final s in sales) {
      final key = '${s.productId}|${s.productName}';
      map[key] = (map[key] ?? 0) + s.profit;
    }
    return map;
  }

  Future<double> monthlyTotalProfit(int year, int month) async {
    final sales = await salesForMonth(year, month);
    return sales.fold<double>(0.0, (sum, s) => sum + s.profit);
  }

  Future<List<String>> monthsWithData() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT DISTINCT substr(date,1,7) as ym FROM sales ORDER BY ym DESC");
    return result.map((r) => r['ym'] as String).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BACKUP & RESTORE
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> backupDatabase() async {
    final db = await database;
    final dbPath = db.path;

    // Save to Downloads folder
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(':', '-')
        .replaceAll('T', '_');
    final backupPath = p.join(dir!.path, 'profit_backup_$timestamp.db');
    await File(dbPath).copy(backupPath);
    return backupPath;
  }

  Future<bool> restoreDatabase(String backupPath) async {
    try {
      final db = await database;
      final dbPath = db.path;

      // Close the current database
      await db.close();
      _db = null;

      // Copy backup over current db
      await File(backupPath).copy(dbPath);

      // Reopen
      _db = await _initDB('profit_tracker.db');
      return true;
    } catch (e) {
      return false;
    }
  }

  String get dbFileName => 'profit_tracker.db';
}