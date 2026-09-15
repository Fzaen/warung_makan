import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

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

    print("--- Inisialisasi Database ---");
    print("Lokasi DB: $path");

    bool shouldCopy = false;

    // 1. Cek apakah file fisik ada
    final exists = await File(path).exists();

    if (!exists) {
      print("File database tidak ada. Harus copy.");
      shouldCopy = true;
    } else {
      // 2. Cek apakah tabel dan kolom lengkap
      try {
        final db = await openDatabase(path);
        final usersTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
        final cartTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='pos_cart'");
        
        // Cek kolom baru 'itm_cost_price' di sale_items
        final saleItemsInfo = await db.rawQuery("PRAGMA table_info(sale_items)");
        bool hasCostPrice = saleItemsInfo.any((col) => col['name'] == 'itm_cost_price');
        
        await db.close();
        
        if (usersTable.isEmpty || cartTable.isEmpty || !hasCostPrice) {
          print("Skema database tidak lengkap atau versi lama. Menimpa dengan file assets...");
          shouldCopy = true;
        }
      } catch (e) {
        print("Error saat mengecek tabel: $e. Harus timpa.");
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      if (exists) {
        await File(path).delete();
      }
      await _copyDatabaseFromAssets(path, filePath);
    }

    return await openDatabase(path, version: 1);
  }

  Future<void> _copyDatabaseFromAssets(String path, String filePath) async {
    try {
      await Directory(dirname(path)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/db/$filePath");
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      print("DATABASE BERHASIL DISALIN DARI ASSETS!");
    } catch (e) {
      print("GAGAL MENYALIN DATABASE: $e");
      rethrow;
    }
  }

  // ==========================================
  // FUNGSI MASTER DATA
  // ==========================================
  
  Future<List<String>> getMainCategories() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT cat_name FROM categories');
    return result.map((row) => row['cat_name'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getProductsByMainCategory(String? mainCategory) async {
    final db = await instance.database;
    if (mainCategory == null) {
      return await db.query('products');
    }
    return await db.rawQuery('''
      SELECT p.* FROM products p
      JOIN categories c ON p.prd_category_id = c.cat_id
      WHERE c.cat_name = ?
    ''', [mainCategory]);
  }

  // ==========================================
  // FUNGSI AUTHENTICATION
  // ==========================================
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'usr_username = ? AND usr_password = ? AND usr_is_active = 1',
      whereArgs: [username, password],
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // ==========================================
  // FUNGSI POS CART (TEMPORARY SALES)
  // ==========================================
  
  Future<void> addToCart(int userId, String prdSku, int qty, double sellingPrice, double costPrice) async {
    final db = await instance.database;
    
    final existing = await db.query(
      'pos_cart',
      where: 'cart_user_id = ? AND cart_prd_sku = ? AND cart_status = 0',
      whereArgs: [userId, prdSku],
    );

    if (existing.isNotEmpty) {
      int newQty = (existing.first['cart_qty'] as int) + qty;
      await updateCartQty(existing.first['cart_id'] as int, newQty);
    } else {
      await db.insert('pos_cart', {
        'cart_user_id': userId,
        'cart_prd_sku': prdSku,
        'cart_qty': qty,
        'cart_price': sellingPrice,
        'cart_cost_price': costPrice, // Simpan harga modal
        'cart_subtotal': qty * sellingPrice,
        'cart_status': 0
      });
    }
  }

  Future<void> updateCartQty(int cartId, int newQty) async {
    final db = await instance.database;
    if (newQty <= 0) {
      await removeFromCart(cartId);
    } else {
      final item = await db.query('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
      if (item.isNotEmpty) {
        double price = item.first['cart_price'] as double;
        await db.update(
          'pos_cart',
          {
            'cart_qty': newQty,
            'cart_subtotal': newQty * price
          },
          where: 'cart_id = ?',
          whereArgs: [cartId],
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> getActiveCart(int userId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.*, p.prd_name, p.prd_image, p.prd_cost_price 
      FROM pos_cart c
      JOIN products p ON c.cart_prd_sku = p.prd_sku
      WHERE c.cart_user_id = ? AND c.cart_status = 0
    ''', [userId]);
  }

  Future<void> removeFromCart(int cartId) async {
    final db = await instance.database;
    await db.delete('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
  }

  // ==========================================
  // FUNGSI TRANSAKSI PENJUALAN (SALES)
  // ==========================================

  Future<String> processPayment({
    required int userId,
    required double subtotal,
    required double paidAmount,
    required double changeAmount,
    String paymentMethod = 'Tunai',
  }) async {
    final db = await instance.database;
    
    String datePart = DateFormat('yyyyMMdd').format(DateTime.now());
    final lastSale = await db.rawQuery('SELECT sls_invoice_number FROM sales ORDER BY sls_transaction_date DESC LIMIT 1');
    int sequence = 1;
    if (lastSale.isNotEmpty) {
      String lastInv = lastSale.first['sls_invoice_number'] as String;
      if (lastInv.contains(datePart)) {
        String lastSeqStr = lastInv.split('-').last;
        sequence = int.parse(lastSeqStr) + 1;
      }
    }
    String invoiceNumber = 'INV-$datePart-${sequence.toString().padLeft(4, '0')}';

    await db.transaction((txn) async {
      // Ambil item dari cart
      final cartItems = await txn.query('pos_cart', where: 'cart_user_id = ? AND cart_status = 0', whereArgs: [userId]);
      
      // Hitung total jumlah item (Quantity)
      int totalQty = cartItems.fold(0, (sum, item) => sum + (item['cart_qty'] as int));

      // 1. Simpan ke tabel SALES
      await txn.insert('sales', {
        'sls_invoice_number': invoiceNumber,
        'sls_user_id': userId,
        'sls_subtotal': subtotal,
        'sls_discount_amount': 0,
        'sls_grand_total': subtotal,
        'sls_paid_amount': paidAmount,
        'sls_change_amount': changeAmount,
        'sls_payment_method': paymentMethod,
        'sls_total_item': totalQty, // Kolom baru: Total Qty per Invoice
      });

      // 2. Pindahkan item ke sale_items
      for (var item in cartItems) {
        await txn.insert('sale_items', {
          'itm_sale_id': invoiceNumber,
          'itm_sku': item['cart_prd_sku'],
          'itm_discount': 0,
          'itm_cashback': 0,
          'itm_quantity': item['cart_qty'],
          'itm_unit_price': item['cart_price'],
          'itm_cost_price': item['cart_cost_price'], // Simpan harga modal saat ini
          'itm_subtotal': item['cart_subtotal'],
        });
      }

      // 3. Update status pos_cart
      await txn.update(
        'pos_cart',
        {'cart_status': 1},
        where: 'cart_user_id = ? AND cart_status = 0',
        whereArgs: [userId],
      );
    });

    return invoiceNumber;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
