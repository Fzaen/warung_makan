import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'pages/admin/master_user_page.dart';
import 'pages/admin/master_product_page.dart';
import 'pages/pos/pos_page.dart';
import 'pages/home_page.dart';

import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Memastikan Flutter binding diinisialisasi
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi khusus jika dijalankan di Windows atau Linux (Desktop)
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warung Makan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Menetapkan Halaman Login sebagai layar utama saat aplikasi dibuka
      home: const LoginView(),
    );
  }
}

/// ===========================================================================
/// HALAMAN LOGIN
/// ===========================================================================
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Fungsi untuk memvalidasi login ke database
  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username dan Password tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Panggil fungsi login dari DatabaseHelper
      final user = await DatabaseHelper.instance.login(username, password);
      
      if (user != null) {
        if (!mounted) return;
        // Pindah ke halaman Navigasi Utama jika sukses
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(user: user),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username atau Password salah!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan database: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu, size: 100, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'WARUNG MAKAN',
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.blue
                ),
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'MASUK', 
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===========================================================================
/// NAVIGASI UTAMA (SETELAH LOGIN)
/// ===========================================================================
class MainNavigation extends StatefulWidget {
  final Map<String, dynamic> user; // Data user dari database
  const MainNavigation({super.key, required this.user});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navItems;

  @override
  void initState() {
    super.initState();
    _setupNavigation();
  }

  void _setupNavigation() {
    final roleId = widget.user['usr_role_id'];

    // Halaman Beranda (Home) tersedia untuk semua user
    _pages = [HomePage(user: widget.user)];
    _navItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
    ];

    // Menu POS (Point of Sale) tersedia untuk semua user
    _pages.add(PosPage(user: widget.user));
    _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'POS'));

    // Menu khusus Admin (Role ID 1)
    if (roleId == 1) {
      _pages.add(const MasterProductPage());
      _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Produk'));
      
      _pages.add(const MasterUserPage());
      _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'User'));
    }
  }

  // Fungsi untuk menampilkan dialog konfirmasi sebelum logout
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Keluar'),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi? Transaksi yang belum selesai mungkin akan hilang.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Menutup dialog saja
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginView()),
                );
              },
              child: const Text('KELUAR', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah halaman yang aktif adalah POS
    int posIndex = _navItems.indexWhere((item) => item.label == 'POS');
    bool isPosPage = _selectedIndex == posIndex;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 45, // Perkecil ukuran AppBar
        centerTitle: true,
        title: const Text(
          'POS Warung Makan', 
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            // Ikon silang jika di POS, ikon logout jika di Home
            icon: Icon(_selectedIndex == 0 ? Icons.logout : Icons.close),
            onPressed: () {
              if (_selectedIndex == 0) {
                _showLogoutDialog();
              } else {
                setState(() {
                  _selectedIndex = 0; // Kembali ke Home
                });
              }
            },
          )
        ],
      ),
      body: _pages[_selectedIndex],
      // Sembunyikan navbar jika sedang di menu POS agar lebih luas
      bottomNavigationBar: isPosPage 
        ? null 
        : BottomNavigationBar(
            currentIndex: _selectedIndex,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.grey,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            items: _navItems,
          ),
    );
  }
}
