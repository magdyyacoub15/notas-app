import 'dart:async';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/custom_page.dart'; // ⭐ استيراد النموذج
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  static const String tableName = 'transactions';
  static const String customPagesTableName = 'custom_pages'; // ⭐ اسم جدول الصفحات
  static sql.Database? _database;

  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static const _databaseVersion = 5; // ⭐ زيادة الرقم بسبب إضافة جدول جديد
  
  String get _databaseName {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    return '${uid}_finance_app.db';
  }

  Future<sql.Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<sql.Database> _initDb() async {
    String path = join(await sql.getDatabasesPath(), _databaseName);
    return await sql.openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(sql.Database db, int version) async {
    // ⭐ إنشاء جدول المعاملات
    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        date INTEGER NOT NULL,
        partyType TEXT NOT NULL,
        notes TEXT,
        phoneNumber TEXT 
      )
    ''');

    // ⭐ إنشاء جدول الصفحات المخصصة
    await db.execute('''
      CREATE TABLE $customPagesTableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        partyType TEXT NOT NULL
      )
    ''');
  }
// في DatabaseHelper - أضف هذه الدالة
  Future<int> updateCustomPage(CustomPage page) async {
    final db = await instance.database;
    return await db.update(
      customPagesTableName,
      {
        'title': page.title,
        'partyType': page.partyType,
      },
      where: 'id = ?',
      whereArgs: [page.id],
    );
  }
  // في class DatabaseHelper أضف/تأكد من وجود هذه الدالة:

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await instance.database;
    return await db.update(
      tableName,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future _onUpgrade(sql.Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      // ⭐ الترقية من الإصدار 4 إلى 5: إضافة جدول الصفحات المخصصة
      if (oldVersion == 4 && newVersion == 5) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS $customPagesTableName (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            partyType TEXT NOT NULL
          )
        ''');
      } else {
        // ⭐ للترقيات الأخرى، استخدم الطريقة القديمة
        await db.execute("DROP TABLE IF EXISTS $tableName");
        await _onCreate(db, newVersion);
      }
    }
  }

  Future<String> getDatabasePath() async {
    String path = join(await sql.getDatabasesPath(), _databaseName);
    return path;
  }

  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ----------------------------------------------------
  // ⭐ دوال إدارة الصفحات المخصصة (الجديدة)
  // ----------------------------------------------------

  Future<int> insertCustomPage(CustomPage page) async {
    final db = await instance.database;
    return await db.insert(
      customPagesTableName,
      {
        'id': page.id,
        'title': page.title,
        'partyType': page.partyType,
      },
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteCustomPage(String id) async {
    final db = await instance.database;
    return await db.delete(
      customPagesTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CustomPage>> getCustomPages() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(customPagesTableName);
    return List.generate(maps.length, (i) {
      return CustomPage(
        id: maps[i]['id'] as String,
        title: maps[i]['title'] as String,
        partyType: maps[i]['partyType'] as String,
      );
    });
  }

  // ----------------------------------------------------
  // دوال إدارة المعاملات (كما هي)
  // ----------------------------------------------------

  Future<List<Transaction>> getTransactions() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      return Transaction.fromMap(maps[i]);
    });
  }

  Future<int> insertTransaction(Transaction transaction) async {
    final db = await instance.database;
    final map = transaction.toMap();
    return await db.insert(
      tableName,
      map,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }



  Future<int> updateAccountDetails(String oldName, String newName, String partyType, String? newPhoneNumber) async {
    final db = await instance.database;

    final Map<String, dynamic> values = {
      'title': newName,
      'phoneNumber': newPhoneNumber,
    };

    return await db.update(
      tableName,
      values,
      where: 'title = ? AND partyType = ?',
      whereArgs: [oldName, partyType],
    );
  }

  Future<String?> getAccountPhoneNumber(String accountName, String partyType) async {
    final db = await instance.database;

    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      columns: ['phoneNumber'],
      where: 'title = ? AND partyType = ? AND phoneNumber IS NOT NULL',
      whereArgs: [accountName, partyType],
      limit: 1,
      orderBy: 'date DESC',
    );

    if (maps.isNotEmpty) {
      final dynamic phoneData = maps.first['phoneNumber'];

      if (phoneData != null) {
        return phoneData.toString();
      }
    }
    return null;
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTransactionsByAccount(String accountName, String partyType) async {
    final db = await instance.database;
    return await db.delete(
      tableName,
      where: 'title = ? AND partyType = ?',
      whereArgs: [accountName, partyType],
    );
  }
}