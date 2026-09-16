import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(int) onNavigate; // Fungsi untuk berpindah tab

  const HomePage({super.key, required this.user, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _todayCount = 0;
  double _todayOmzet = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // Muat data statistik dari database
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await DatabaseHelper.instance.getTodayStats();
    setState(() {
      _todayCount = stats['count'];
      _todayOmzet = (stats['omzet'] as num).toDouble();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats, // Tarik ke bawah untuk refresh data
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Datang,',
                style: TextStyle(fontSize: 18, color: Colors.grey[700]),
              ),
              Text(
                widget.user['usr_name'],
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 30),

              Row(
                children: [
                  _buildSummaryCard(
                    context,
                    title: 'Transaksi Hari Ini',
                    value: '$_todayCount',
                    icon: Icons.receipt_long,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 15),
                  _buildSummaryCard(
                    context,
                    title: 'Total Omzet',
                    value: currencyFormat.format(_todayOmzet),
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 30),

              const Text(
                'Menu Cepat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              
              // Menu Cepat: POS
              _buildQuickMenu(
                title: 'Buka Kasir (POS)',
                subtitle: 'Mulai transaksi baru',
                icon: Icons.shopping_cart,
                color: Colors.blue,
                onTap: () => widget.onNavigate(1), // Index POS
              ),
              
              const Divider(),
              
              // Menu Cepat: Produk (Khusus Admin)
              if (widget.user['usr_role_id'] == 1) ...[
                _buildQuickMenu(
                  title: 'Manajemen Produk',
                  subtitle: 'Tambah atau ubah data produk',
                  icon: Icons.inventory,
                  color: Colors.purple,
                  onTap: () => widget.onNavigate(2), // Index Produk
                ),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMenu({
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSummaryCard(BuildContext context,
      {required String title, required String value, required IconData icon, required Color color}) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _isLoading 
                ? const SizedBox(height: 30, width: 30, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
