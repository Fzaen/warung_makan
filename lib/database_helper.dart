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

    print("--- Inisialisasi Database ---");
    print("Lokasi DB: $path");

    bool shouldCopy = false;

    // 1. Cek apakah file fisik ada
    final exists = await File(path).exists();

    if (!exists) {
      print("File database tidak ada. Harus copy.");
      shouldCopy = true;
    } else {
      // 2. Jika file ada, cek apakah tabel 'users' dan 'pos_cart' ada di dalamnya
      try {
        final db = await openDatabase(path);
        final usersTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
        final cartTable = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='pos_cart'");
        await db.close();
        
        if (usersTable.isEmpty || cartTable.isEmpty) {
          print("Tabel penting tidak lengkap. Harus timpa.");
          shouldCopy = true;
        }
      } catch (e) {
        print("Error saat mengecek tabel: $e. Harus timpa.");
        shouldCopy = true;
      }
    }

    if (shouldCopy) {
      // Hapus file lama jika ada agar tidak konflik saat ditimpa
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
  
  // Mengambil semua kategori yang ada
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await instance.database;
    return await db.query('categories');
  }

  // Mengambil kategori utama yang unik (Makanan, Minuman, Cemilan)
  Future<List<String>> getMainCategories() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT DISTINCT cat_name FROM categories');
    return result.map((row) => row['cat_name'] as String).toList();
  }

  // Mengambil produk berdasarkan nama kategori utama
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
  
  // Menambah item ke keranjang (atau update qty jika sudah ada)
  Future<void> addToCart(int userId, String prdSku, int qty, double price) async {
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
        'cart_price': price,
        'cart_subtotal': qty * price,
        'cart_status': 0
      });
    }
  }

  // Update quantity spesifik (bisa bertambah atau berkurang)
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

  // Mengambil semua item keranjang yang sedang aktif (status 0)
  Future<List<Map<String, dynamic>>> getActiveCart(int userId) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.*, p.prd_name, p.prd_image 
      FROM pos_cart c
      JOIN products p ON c.cart_prd_sku = p.prd_sku
      WHERE c.cart_user_id = ? AND c.cart_status = 0
    ''', [userId]);
  }

  // Menghapus item tertentu dari keranjang
  Future<void> removeFromCart(int cartId) async {
    final db = await instance.database;
    await db.delete('pos_cart', where: 'cart_id = ?', whereArgs: [cartId]);
  }

  // Mengosongkan keranjang saat transaksi dibayar atau dibatalkan
  Future<void> completeCart(int userId, String invoiceNumber) async {
    final db = await instance.database;
    // Ubah status jadi 1 (selesai) agar tidak muncul lagi di POS
    await db.update(
      'pos_cart',
      {'cart_status': 1},
      where: 'cart_user_id = ? AND cart_status = 0',
      whereArgs: [userId],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
