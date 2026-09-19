import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';
import 'pages/admin/master_user_page.dart';
import 'pages/admin/master_product_page.dart';
import 'pages/admin/report_hub_page.dart';
import 'pages/admin/settings_page.dart';
import 'pages/pos/pos_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Bersihkan file temporary export lama saat aplikasi dibuka
  await DatabaseHelper.instance.clearExportFolder();
  
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
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
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

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi username dan password')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await DatabaseHelper.instance.login(username, password);
      if (user != null) {
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => MainNavigation(user: user)));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Gagal!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Image.asset('assets/logo/soto_banjar_kuin.png', width: 120, height: 120),
              const SizedBox(height: 16),
              const Text('WARUNG MAKAN', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.blue)),
              const SizedBox(height: 40),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
                child: Column(
                  children: [
                    TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                    const SizedBox(height: 16),
                    TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('MASUK', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
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
/// NAVIGASI UTAMA
/// ===========================================================================
class MainNavigation extends StatefulWidget {
  final Map<String, dynamic> user;
  const MainNavigation({super.key, required this.user});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late List<Widget> _pages;
  late List<BottomNavigationBarItem> _navItems;
  String _currentTime = "";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupNavigation();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    if (!mounted) return;
    setState(() {
      _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
    });
  }

  void _setupNavigation() {
    final roleId = widget.user['usr_role_id'];
    _pages = [HomePage(user: widget.user, onNavigate: (i) => setState(() => _selectedIndex = i))];
    _navItems = [const BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 20), activeIcon: Icon(Icons.home, size: 22), label: 'Home')];
    _pages.add(PosPage(user: widget.user));
    _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined, size: 20), activeIcon: Icon(Icons.shopping_cart, size: 22), label: 'POS'));

    if (roleId == 1) {
      _pages.add(const MasterProductPage());
      _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined, size: 20), activeIcon: Icon(Icons.inventory_2, size: 22), label: 'Produk'));
      _pages.add(const MasterUserPage());
      _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.people_outline, size: 20), activeIcon: Icon(Icons.people, size: 22), label: 'User'));
      
      _pages.add(const ReportHubPage());
      _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.assessment_outlined, size: 20), activeIcon: Icon(Icons.assessment, size: 22), label: 'Report'));
      
      _pages.add(const SettingsPage());
      _navItems.add(const BottomNavigationBarItem(icon: Icon(Icons.settings_outlined, size: 20), activeIcon: Icon(Icons.settings, size: 22), label: 'Setting'));
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Aplikasi?'),
        content: const Text('Anda akan dialihkan ke halaman login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginView()));
            },
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isPosPage = _navItems[_selectedIndex].label == 'POS';
    bool isProductPage = _navItems[_selectedIndex].label == 'Produk';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          centerTitle: false,
          automaticallyImplyLeading: false,
          title: Row(
            children: [
              const Icon(Icons.circle, size: 8, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '${widget.user['usr_name'].toString().toUpperCase()}  |  $_currentTime',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(_selectedIndex == 0 ? Icons.logout : Icons.close, size: 18, color: _selectedIndex == 0 ? Colors.red : Colors.grey),
                onPressed: () {
                  if (_selectedIndex == 0) _showLogoutDialog();
                  else setState(() => _selectedIndex = 0);
                },
              ),
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
      // Sembunyikan navbar utama jika di halaman POS atau PRODUK (karena PRODUK punya navbar sendiri)
      bottomNavigationBar: (isPosPage || isProductPage) ? null : Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          onTap: (index) => setState(() => _selectedIndex = index),
          items: _navItems,
        ),
      ),
    );
  }
}
