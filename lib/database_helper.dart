import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('warung_makan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Cek apakah database sudah ada di storage internal HP
    final exists = await databaseExists(path);

    if (!exists) {
      // Jika belum ada, copy dari assets project
      try {
        await Directory(dirname(path)).create(recursive: true);
        
        ByteData data = await rootBundle.load(join("assets", "db", filePath));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        print("Error copying database: $e");
      }
    }

    return await openDatabase(path, version: 1);
  }

  Future _createDB(Database db, int version) async {
    const textType = 'TEXT NOT NULL';
    const textTypeNullable = 'TEXT';
    const boolType = 'INTEGER NOT NULL DEFAULT 1'; // SQLite uses 0/1 for booleans
    const intType = 'INTEGER NOT NULL';
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const numericType = 'REAL NOT NULL'; // SQLite uses REAL for decimal values

    await db.execute('''
      CREATE TABLE roles (
        rol_id $idType,
        rol_name $textType,
        rol_description $textTypeNullable,
        rol_created_at TEXT DEFAULT (datetime('now', 'localtime'))
      )
    ''');

    await db.execute('''
      CREATE TABLE users (
        usr_id $idType,
        usr_role_id $intType,
        usr_name $textType,
        usr_username TEXT UNIQUE NOT NULL,
        usr_password $textType,
        usr_phone $textTypeNullable,
        usr_is_active $boolType,
        usr_created_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (usr_role_id) REFERENCES roles (rol_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        cat_id $idType,
        cat_name $textType,
        cat_subname $textTypeNullable,
        cat_slug $textTypeNullable
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        prd_id INTEGER PRIMARY KEY AUTOINCREMENT,
        prd_sku TEXT UNIQUE,
        prd_category_id $intType,
        prd_name $textType,
        prd_cost_price $numericType,
        prd_selling_price $numericType,
        prd_unit $textTypeNullable,
        prd_image $textTypeNullable,
        prd_created_at TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (prd_category_id) REFERENCES categories (cat_id)
      )
    ''');

    await db.execute('''
      CREATE TRIGGER trg_generate_sku 
      AFTER INSERT ON products
      BEGIN
          UPDATE products 
          SET prd_sku = PRINTF('%05d', NEW.prd_id) 
          WHERE prd_id = NEW.prd_id;
      END;
    ''');

    await db.execute('''
      CREATE TABLE sales (
        sls_invoice_number TEXT PRIMARY KEY,
        sls_user_id $intType,
        sls_subtotal $numericType,
        sls_discount_amount REAL DEFAULT 0,
        sls_grand_total $numericType,
        sls_paid_amount $numericType,
        sls_change_amount $numericType,
        sls_payment_method $textTypeNullable,
        sls_transaction_date TEXT DEFAULT (datetime('now', 'localtime')),
        FOREIGN KEY (sls_user_id) REFERENCES users (usr_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        itm_id $idType,
        itm_sale_id TEXT NOT NULL,
        itm_sku TEXT NOT NULL,
        itm_discount REAL NOT NULL,
        itm_cashback REAL NOT NULL,
        itm_quantity $intType,
        itm_unit_price $numericType,
        itm_subtotal $numericType,
        FOREIGN KEY (itm_sale_id) REFERENCES sales (sls_invoice_number),
        FOREIGN KEY (itm_sku) REFERENCES products (prd_sku)
      )
    ''');

    await db.execute('''
      CREATE TABLE promotions (
        prm_code TEXT PRIMARY KEY,
        prm_name $textType,
        prm_type $textTypeNullable,
        prm_value $numericType,
        prm_min_purchase REAL DEFAULT 0,
        prm_max_discount REAL,
        prm_start_date $textTypeNullable,
        prm_end_date $textTypeNullable,
        prm_is_active $boolType
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_promotions (
        sprm_id $idType,
        sprm_sale_id TEXT NOT NULL,
        sprm_promotion_id TEXT NOT NULL,
        sprm_discount_applied $numericType,
        FOREIGN KEY (sprm_sale_id) REFERENCES sales (sls_invoice_number),
        FOREIGN KEY (sprm_promotion_id) REFERENCES promotions (prm_code)
      )
    ''');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
