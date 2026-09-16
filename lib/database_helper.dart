import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

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
        
        // Cek kolom baru 'prd_is_active' di products
        final productsInfo = await db.rawQuery("PRAGMA table_info(products)");
        bool hasPrdActive = productsInfo.any((col) => col['name'] == 'prd_is_active');
        
        // Cek tabel log
        final logTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='pos_logs'");
        
        await db.close();
        
        if (logTable.isEmpty || !hasPrdActive) {
          print("Skema database versi lama atau tidak lengkap. Menimpa dengan file assets...");
          shouldCopy = true;
        }
      } catch (e) {
        print("Error saat mengecek tabel: $e. Harus timpa.");
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      try {
        if (exists) {
          await File(path).delete();
        }
        await _copyDatabaseFromAssets(path, filePath);
      } catch (e) {
        print("Gagal memperbarui database: $e");
      }
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
  // FUNGSI MASTER DATA & CRUD
  // ==========================================
  
  // ROLES
  Future<List<Map<String, dynamic>>> getRoles() async {
    final db = await instance.database;
    return await db.query('roles');
  }

  // CATEGORIES
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  Future<List<String>> getMainCategories() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT cat_name FROM categories');
    return result.map((row) => row['cat_name'] as String).toList();
  }

  // USERS
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT u.*, r.rol_name 
      FROM users u
      JOIN roles r ON u.usr_role_id = r.rol_id
      ORDER BY u.usr_name ASC
    ''');
  }

  Future<int> addUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.insert('users', user);
  }

  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await instance.database;
    return await db.update('users', user, where: 'usr_id = ?', whereArgs: [id]);
  }

  // PRODUCTS
  Future<List<Map<String, dynamic>>> getAllProducts({String? mainCategory}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (mainCategory != null) {
      whereClause = 'WHERE c.cat_name = ?';
      whereArgs = [mainCategory];
    }

    return await db.rawQuery('''
      SELECT p.*, c.cat_name, c.cat_subname 
      FROM products p
      JOIN categories c ON p.prd_category_id = c.cat_id
      $whereClause
      ORDER BY p.prd_sku ASC
    ''', whereArgs);
  }

  Future<String> generateNextSku(String mainCategory) async {
    final db = await instance.database;
    String prefix = '1'; // Default Makanan
    if (mainCategory == 'Minuman') prefix = '2';
    if (mainCategory == 'Cemilan') prefix = '3';

    final result = await db.rawQuery('''
      SELECT MAX(prd_sku) as last_sku FROM products 
      WHERE prd_sku LIKE '$prefix%' AND length(prd_sku) = 5
    ''');

    if (result.isNotEmpty && result.first['last_sku'] != null) {
      int lastNum = int.parse(result.first['last_sku'] as String);
      return (lastNum + 1).toString();
    } else {
      return '${prefix}0001';
    }
  }

  Future<List<Map<String, dynamic>>> getProductsByMainCategory(String? mainCategory) async {
    final db = await instance.database;
    // Hanya ambil produk yang aktif (prd_is_active = 1) untuk POS
    if (mainCategory == null) {
      return await db.query('products', where: 'prd_is_active = 1', orderBy: 'prd_sku ASC');
    }
    return await db.rawQuery('''
      SELECT p.* FROM products p
      JOIN categories c ON p.prd_category_id = c.cat_id
      WHERE c.cat_name = ? AND p.prd_is_active = 1
      ORDER BY p.prd_sku ASC
    ''', [mainCategory]);
  }

  Future<int> addProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.insert('products', product);
  }

  Future<int> updateProduct(String sku, Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.update('products', product, where: 'prd_sku = ?', whereArgs: [sku]);
  }

  // IMAGE HANDLING
  Future<String> saveProductImage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'product_images');
    await Directory(path).create(recursive: true);
    
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${extension(imageFile.path)}';
    final savedFile = await imageFile.copy(join(path, fileName));
    return fileName; // Simpan hanya nama filenya
  }

  Future<File?> getLocalProductImage(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(join(directory.path, 'product_images', fileName));
    if (await file.exists()) return file;
    return null;
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
  // FUNGSI LOGGING (POS LOGS)
  // ==========================================
  Future<List<Map<String, dynamic>>> getPosLogs({String? startDate, String? endDate}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null && endDate != null) {
      whereClause = 'WHERE DATE(log_timestamp) BETWEEN DATE(?) AND DATE(?)';
      whereArgs = [startDate, endDate];
    }

    return await db.rawQuery('''
      SELECT l.*, u.usr_name, p.prd_name 
      FROM pos_logs l
      JOIN users u ON l.log_user_id = u.usr_id
      JOIN products p ON l.log_prd_sku = p.prd_sku
      $whereClause
      ORDER BY l.log_timestamp DESC
    ''', whereArgs);
  }

  Future<void> addPosLog({
    required int userId,
    required String prdSku,
    required String action,
    required int oldQty,
    required int newQty,
    String? description,
  }) async {
    final db = await instance.database;
    await db.insert('pos_logs', {
      'log_user_id': userId,
      'log_prd_sku': prdSku,
      'log_action': action,
      'log_old_qty': oldQty,
      'log_new_qty': newQty,
      'log_description': description,
    });
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
      await updateCartQty(userId, existing.first['cart_id'] as int, newQty);
    } else {
      await db.insert('pos_cart', {
        'cart_user_id': userId,
        'cart_prd_sku': prdSku,
        'cart_qty': qty,
        'cart_price': sellingPrice,
        'cart_cost_price': costPrice,
        'cart_subtotal': qty * sellingPrice,
        'cart_status': 0
      });
    }
  }

  Future<void> updateCartQty(int userId, int cartId, int newQty) async {
    final db = await instance.database;
    
    final item = await db.query('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
    if (item.isNotEmpty) {
      int oldQty = item.first['cart_qty'] as int;
      String sku = item.first['cart_prd_sku'] as String;
      double price = item.first['cart_price'] as double;

      if (newQty <= 0) return;

      if (newQty < oldQty) {
        await addPosLog(
          userId: userId,
          prdSku: sku,
          action: 'REDUCE',
          oldQty: oldQty,
          newQty: newQty,
          description: 'Pengurangan kuantitas di keranjang'
        );
      }

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

  Future<List<Map<String, dynamic>>> getActiveCart(int userId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.*, p.prd_name, p.prd_image, p.prd_cost_price 
      FROM pos_cart c
      JOIN products p ON c.cart_prd_sku = p.prd_sku
      WHERE c.cart_user_id = ? AND c.cart_status = 0
    ''', [userId]);
  }

  Future<void> removeFromCart(int userId, int cartId) async {
    final db = await instance.database;
    
    final item = await db.query('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
    if (item.isNotEmpty) {
      int oldQty = item.first['cart_qty'] as int;
      String sku = item.first['cart_prd_sku'] as String;

      await addPosLog(
        userId: userId,
        prdSku: sku,
        action: 'DELETE',
        oldQty: oldQty,
        newQty: 0,
        description: 'Penghapusan item dari keranjang'
      );

      await db.delete('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
    }
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
      final cartItems = await txn.query('pos_cart', where: 'cart_user_id = ? AND cart_status = 0', whereArgs: [userId]);
      int totalVarian = cartItems.length;

      await txn.insert('sales', {
        'sls_invoice_number': invoiceNumber,
        'sls_user_id': userId,
        'sls_subtotal': subtotal,
        'sls_discount_amount': 0,
        'sls_grand_total': subtotal,
        'sls_paid_amount': paidAmount,
        'sls_change_amount': changeAmount,
        'sls_payment_method': paymentMethod,
        'sls_total_item': totalVarian,
      });

      for (var item in cartItems) {
        await txn.insert('sale_items', {
          'itm_sale_id': invoiceNumber,
          'itm_sku': item['cart_prd_sku'],
          'itm_discount': 0,
          'itm_cashback': 0,
          'itm_quantity': item['cart_qty'],
          'itm_unit_price': item['cart_price'],
          'itm_cost_price': item['cart_cost_price'],
          'itm_subtotal': item['cart_subtotal'],
        });
      }

      await txn.update(
        'pos_cart',
        {'cart_status': 1},
        where: 'cart_user_id = ? AND cart_status = 0',
        whereArgs: [userId],
      );
    });

    return invoiceNumber;
  }

  // ==========================================
  // FUNGSI STATISTIK (HOME)
  // ==========================================
  
  Future<Map<String, dynamic>> getTodayStats() async {
    final db = await instance.database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final countResult = await db.rawQuery(
      "SELECT COUNT(*) as total FROM sales WHERE DATE(sls_transaction_date) = ?", 
      [today]
    );

    final sumResult = await db.rawQuery(
      "SELECT SUM(sls_grand_total) as omzet FROM sales WHERE DATE(sls_transaction_date) = ?", 
      [today]
    );

    return {
      'count': countResult.first['total'] ?? 0,
      'omzet': sumResult.first['omzet'] ?? 0.0,
    };
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
