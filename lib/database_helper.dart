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

    final exists = await File(path).exists();

    if (!exists) {
      print("File database tidak ada. Harus copy.");
      shouldCopy = true;
    } else {
      try {
        final db = await openDatabase(path);
        
        final usersTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
        final cartTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='pos_cart'");
        final logTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='pos_logs'");
        final settingsTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='app_settings'");
        
        final productsInfo = await db.rawQuery("PRAGMA table_info(products)");
        bool hasPrdActive = productsInfo.any((col) => col['name'] == 'prd_is_active');
        
        final saleItemsInfo = await db.rawQuery("PRAGMA table_info(sale_items)");
        bool hasCostPrice = saleItemsInfo.any((col) => col['name'] == 'itm_cost_price');

        // Cek kolom baru 'set_paper_size'
        final settingsInfo = await db.rawQuery("PRAGMA table_info(app_settings)");
        bool hasPaperSize = settingsInfo.any((col) => col['name'] == 'set_paper_size');
        
        await db.close();
        
        if (usersTable.isEmpty || cartTable.isEmpty || logTable.isEmpty || settingsTable.isEmpty || !hasPrdActive || !hasCostPrice || !hasPaperSize) {
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
  
  Future<List<Map<String, dynamic>>> getRoles() async {
    final db = await instance.database;
    return await db.query('roles');
  }

  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  Future<List<String>> getMainCategories() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT cat_name FROM categories');
    return result.map((row) => row['cat_name'] as String).toList();
  }

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

  Future<List<Map<String, dynamic>>> getAllProducts({String? mainCategory, String? query}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];
    if (mainCategory != null) { conditions.add('c.cat_name = ?'); whereArgs.add(mainCategory); }
    if (query != null && query.isNotEmpty) { conditions.add('(p.prd_name LIKE ? OR p.prd_sku LIKE ?)'); whereArgs.add('%$query%'); whereArgs.add('%$query%'); }
    if (conditions.isNotEmpty) { whereClause = 'WHERE ${conditions.join(' AND ')}'; }

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
    String prefix = '1';
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

  Future<List<Map<String, dynamic>>> getProductsByMainCategory(String? mainCategory, {String? query}) async {
    final db = await instance.database;
    List<String> conditions = ['p.prd_is_active = 1'];
    List<dynamic> whereArgs = [];
    if (mainCategory != null) { conditions.add('c.cat_name = ?'); whereArgs.add(mainCategory); }
    if (query != null && query.isNotEmpty) { conditions.add('(p.prd_name LIKE ? OR p.prd_sku LIKE ?)'); whereArgs.add('%$query%'); whereArgs.add('%$query%'); }
    return await db.rawQuery('''
      SELECT p.* FROM products p
      JOIN categories c ON p.prd_category_id = c.cat_id
      WHERE ${conditions.join(' AND ')}
      ORDER BY p.prd_sku ASC
    ''', whereArgs);
  }

  Future<int> addProduct(Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.insert('products', product);
  }

  Future<int> updateProduct(String sku, Map<String, dynamic> product) async {
    final db = await instance.database;
    return await db.update('products', product, where: 'prd_sku = ?', whereArgs: [sku]);
  }

  Future<String> saveProductImage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'product_images');
    await Directory(path).create(recursive: true);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${extension(imageFile.path)}';
    await imageFile.copy(join(path, fileName));
    return fileName;
  }

  Future<File?> getLocalProductImage(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(join(directory.path, 'product_images', fileName));
    if (await file.exists()) return file;
    return null;
  }

  // ==========================================
  // FUNGSI APP SETTINGS
  // ==========================================
  Future<Map<String, dynamic>> getSettings() async {
    final db = await instance.database;
    final res = await db.query('app_settings', where: 'set_id = 1');
    if (res.isNotEmpty) return res.first;
    return {
      'set_warung_name': 'WARUNG MAKAN',
      'set_address': 'Jl. Raya Kuin No. 123',
      'set_phone': '0812-3456-7890',
      'set_default_printer': null,
      'set_paper_size': 80, // Default 80mm
    };
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    final db = await instance.database;
    await db.update('app_settings', settings, where: 'set_id = 1');
  }

  // ==========================================
  // FUNGSI AUTHENTICATION
  // ==========================================
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await instance.database;
    final results = await db.query('users', where: 'usr_username = ? AND usr_password = ? AND usr_is_active = 1', whereArgs: [username, password]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  // ==========================================
  // FUNGSI LOGGING (POS LOGS)
  // ==========================================
  Future<List<Map<String, dynamic>>> getPosLogs({String? startDate, String? endDate}) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    if (startDate != null && endDate != null) { whereClause = 'WHERE DATE(log_timestamp) BETWEEN DATE(?) AND DATE(?)'; whereArgs = [startDate, endDate]; }
    return await db.rawQuery('''
      SELECT l.*, u.usr_name, p.prd_name 
      FROM pos_logs l
      JOIN users u ON l.log_user_id = u.usr_id
      JOIN products p ON l.log_prd_sku = p.prd_sku
      $whereClause
      ORDER BY l.log_timestamp DESC
    ''', whereArgs);
  }

  Future<void> addPosLog({required int userId, required String prdSku, required String action, required int oldQty, required int newQty, String? description}) async {
    final db = await instance.database;
    await db.insert('pos_logs', { 'log_user_id': userId, 'log_prd_sku': prdSku, 'log_action': action, 'log_old_qty': oldQty, 'log_new_qty': newQty, 'log_description': description });
  }

  // ==========================================
  // FUNGSI POS CART
  // ==========================================
  
  Future<void> addToCart(int userId, String prdSku, int qty, double sellingPrice, double costPrice) async {
    final db = await instance.database;
    final existing = await db.query('pos_cart', where: 'cart_user_id = ? AND cart_prd_sku = ? AND cart_status = 0', whereArgs: [userId, prdSku]);
    if (existing.isNotEmpty) {
      int newQty = (existing.first['cart_qty'] as int) + qty;
      await updateCartQty(userId, existing.first['cart_id'] as int, newQty);
    } else {
      await db.insert('pos_cart', { 'cart_user_id': userId, 'cart_prd_sku': prdSku, 'cart_qty': qty, 'cart_price': sellingPrice, 'cart_cost_price': costPrice, 'cart_subtotal': qty * sellingPrice, 'cart_status': 0 });
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
      if (newQty < oldQty) { await addPosLog(userId: userId, prdSku: sku, action: 'REDUCE', oldQty: oldQty, newQty: newQty, description: 'Pengurangan kuantitas di keranjang'); }
      await db.update('pos_cart', { 'cart_qty': newQty, 'cart_subtotal': newQty * price }, where: 'cart_id = ?', whereArgs: [cartId]);
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
      await addPosLog(userId: userId, prdSku: sku, action: 'DELETE', oldQty: oldQty, newQty: 0, description: 'Penghapusan item dari keranjang');
      await db.delete('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
    }
  }

  // ==========================================
  // FUNGSI TRANSAKSI PENJUALAN
  // ==========================================

  Future<List<Map<String, dynamic>>> getSalesHistory({required String startDate, required String endDate}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT s.*, u.usr_username 
      FROM sales s
      JOIN users u ON s.sls_user_id = u.usr_id
      WHERE DATE(s.sls_transaction_date) BETWEEN DATE(?) AND DATE(?)
      ORDER BY s.sls_transaction_date DESC
    ''', [startDate, endDate]);
  }

  Future<String> processPayment({required int userId, required double subtotal, required double paidAmount, required double changeAmount, String paymentMethod = 'Tunai'}) async {
    final db = await instance.database;
    String datePart = DateFormat('yyyyMMdd').format(DateTime.now());
    final lastSale = await db.rawQuery('SELECT sls_invoice_number FROM sales ORDER BY sls_transaction_date DESC LIMIT 1');
    int sequence = 1;
    if (lastSale.isNotEmpty) {
      String lastInv = lastSale.first['sls_invoice_number'] as String;
      if (lastInv.contains(datePart)) { sequence = int.parse(lastInv.split('-').last) + 1; }
    }
    String invoiceNumber = 'INV-$datePart-${sequence.toString().padLeft(4, '0')}';
    await db.transaction((txn) async {
      final cartItems = await txn.query('pos_cart', where: 'cart_user_id = ? AND cart_status = 0', whereArgs: [userId]);
      int totalVarian = cartItems.length;
      await txn.insert('sales', { 'sls_invoice_number': invoiceNumber, 'sls_user_id': userId, 'sls_subtotal': subtotal, 'sls_discount_amount': 0, 'sls_grand_total': subtotal, 'sls_paid_amount': paidAmount, 'sls_change_amount': changeAmount, 'sls_payment_method': paymentMethod, 'sls_total_item': totalVarian });
      for (var item in cartItems) {
        await txn.insert('sale_items', { 'itm_sale_id': invoiceNumber, 'itm_sku': item['cart_prd_sku'], 'itm_discount': 0, 'itm_cashback': 0, 'itm_quantity': item['cart_qty'], 'itm_unit_price': item['cart_price'], 'itm_cost_price': item['cart_cost_price'], 'itm_subtotal': item['cart_subtotal'] });
      }
      await txn.update('pos_cart', {'cart_status': 1}, where: 'cart_user_id = ? AND cart_status = 0', whereArgs: [userId]);
    });
    return invoiceNumber;
  }

  Future<Map<String, dynamic>?> getSaleByInvoice(String invoiceNumber) async {
    final db = await instance.database;
    final sale = await db.rawQuery('SELECT s.*, u.usr_username FROM sales s JOIN users u ON s.sls_user_id = u.usr_id WHERE s.sls_invoice_number = ?', [invoiceNumber]);
    if (sale.isEmpty) return null;
    final items = await db.rawQuery('SELECT si.*, p.prd_name FROM sale_items si JOIN products p ON si.itm_sku = p.prd_sku WHERE si.itm_sale_id = ?', [invoiceNumber]);
    return { 'sale': sale.first, 'items': items };
  }

  Future<List<Map<String, dynamic>>> getProfitReport({required String startDate, required String endDate}) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT DATE(sls_transaction_date) as date, COUNT(*) as total_invoices, SUM(sls_grand_total) as total_revenue,
      SUM((SELECT SUM(itm_quantity * itm_cost_price) FROM sale_items WHERE itm_sale_id = sls_invoice_number)) as total_cost
      FROM sales WHERE DATE(sls_transaction_date) BETWEEN DATE(?) AND DATE(?)
      GROUP BY DATE(sls_transaction_date) ORDER BY date DESC
    ''', [startDate, endDate]);
  }

  Future<Map<String, dynamic>> getTodayStats() async {
    final db = await instance.database;
    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final countResult = await db.rawQuery("SELECT COUNT(*) as total FROM sales WHERE DATE(sls_transaction_date) = ?", [today]);
    final sumResult = await db.rawQuery("SELECT SUM(sls_grand_total) as omzet FROM sales WHERE DATE(sls_transaction_date) = ?", [today]);
    return { 'count': countResult.first['total'] ?? 0, 'omzet': sumResult.first['omzet'] ?? 0.0 };
  }

  // ==========================================
  // FUNGSI BACKUP & RESTORE
  // ==========================================
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'warung_makan.db');
  }

  Future<void> restoreDatabase(String backupPath) async {
    final dbPath = await getDatabasePath();
    if (_database != null) { await _database!.close(); _database = null; }
    final backupFile = File(backupPath);
    await backupFile.copy(dbPath);
    await database;
  }

  Future close() async { final db = await instance.database; db.close(); }
}
