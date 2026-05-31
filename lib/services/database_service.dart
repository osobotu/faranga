import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/transaction.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'momo_finance.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tx_id TEXT,
            type TEXT NOT NULL,
            amount INTEGER NOT NULL,
            recipient TEXT NOT NULL,
            phone TEXT,
            timestamp TEXT NOT NULL,
            fee INTEGER NOT NULL,
            balance INTEGER NOT NULL,
            category TEXT,
            raw_sms TEXT NOT NULL UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE category_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            pattern TEXT NOT NULL UNIQUE,
            category TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category TEXT,
            amount INTEGER NOT NULL,
            period TEXT NOT NULL DEFAULT 'monthly'
          )
        ''');
        await _seedCategories(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS category_rules (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              pattern TEXT NOT NULL UNIQUE,
              category TEXT NOT NULL
            )
          ''');
          await _seedCategories(db);
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS budgets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              category TEXT,
              amount INTEGER NOT NULL,
              period TEXT NOT NULL DEFAULT 'monthly'
            )
          ''');
        }
      },
    );
  }

  /// Seed with common Rwandan merchant patterns.
  static Future<void> _seedCategories(Database db) async {
    const seeds = {
      'SUPERMARKET': 'Groceries',
      'PHARMACY': 'Health',
      'HOSPITAL': 'Health',
      'CLINIC': 'Health',
      'RESTAURANT': 'Food & Dining',
      'HOTEL': 'Food & Dining',
      'CAFE': 'Food & Dining',
      'PETROL': 'Transport',
      'FUEL': 'Transport',
      'TAXI': 'Transport',
      'MOTO': 'Transport',
      'SCHOOL': 'Education',
      'UNIVERSITY': 'Education',
      'AIRTEL': 'Telecom',
      'MTN': 'Telecom',
      'ELECTRICITY': 'Utilities',
      'WATER': 'Utilities',
      'WASAC': 'Utilities',
      'RENT': 'Housing',
      'CHURCH': 'Donations',
    };
    for (final entry in seeds.entries) {
      await db.insert('category_rules', {
        'pattern': entry.key,
        'category': entry.value,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  // ── Transactions ──────────────────────────────────────

  static Future<bool> insert(MomoTransaction tx) async {
    final db = await database;
    try {
      await db.insert(
        'transactions',
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<int> insertBatch(List<MomoTransaction> transactions) async {
    int inserted = 0;
    for (final tx in transactions) {
      if (await insert(tx)) inserted++;
    }
    return inserted;
  }

  static Future<List<MomoTransaction>> getAll() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'timestamp DESC');
    return rows.map(MomoTransaction.fromMap).toList();
  }

  static Future<void> updateCategory(int id, String category) async {
    final db = await database;
    await db.update(
      'transactions',
      {'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Category rules ────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCategoryRules() async {
    final db = await database;
    return db.query('category_rules', orderBy: 'pattern ASC');
  }

  static Future<void> addCategoryRule(String pattern, String category) async {
    final db = await database;
    await db.insert('category_rules', {
      'pattern': pattern.toUpperCase(),
      'category': category,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deleteCategoryRule(int id) async {
    final db = await database;
    await db.delete('category_rules', where: 'id = ?', whereArgs: [id]);
  }

  // ── Categories (unified list) ─────────────────────────

  /// Get all categories ever used (built-in + user-created).
  static Future<List<String>> getAllCategories() async {
    final db = await database;

    final fromRules = await db.rawQuery(
      'SELECT DISTINCT category FROM category_rules ORDER BY category',
    );
    final fromTx = await db.rawQuery(
      'SELECT DISTINCT category FROM transactions WHERE category IS NOT NULL ORDER BY category',
    );

    final all = <String>{
      for (final row in fromRules) row['category'] as String,
      for (final row in fromTx) row['category'] as String,
    };

    return all.toList()..sort();
  }

  // ── Budgets ───────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getBudgets() async {
    final db = await database;
    return db.query('budgets');
  }

  static Future<void> setBudget(String? category, int amount) async {
    final db = await database;
    if (category != null) {
      await db.delete('budgets', where: 'category = ?', whereArgs: [category]);
    } else {
      await db.delete('budgets', where: 'category IS NULL');
    }
    await db.insert('budgets', {
      'category': category,
      'amount': amount,
      'period': 'monthly',
    });
  }

  static Future<void> deleteBudget(int id) async {
    final db = await database;
    await db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
