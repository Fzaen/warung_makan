import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  final Function(int) onNavigate;

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
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selamat Datang,', style: TextStyle(fontSize: isMobile ? 16 : 18, color: Colors.grey[700])),
              Text(widget.user['usr_name'], style: TextStyle(fontSize: isMobile ? 22 : 26, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 24),

              // STATISTIK RESPONSIVE: Stack ke bawah jika Portrait & Mobile
              isPortrait && isMobile
              ? Column(
                  children: [
                    _buildSummaryCard(context, title: 'Transaksi Hari Ini', value: '$_todayCount', icon: Icons.receipt_long, color: Colors.orange, isFullWidth: true),
                    const SizedBox(height: 12),
                    _buildSummaryCard(context, title: 'Total Omzet', value: currencyFormat.format(_todayOmzet), icon: Icons.payments, color: Colors.green, isFullWidth: true),
                  ],
                )
              : Row(
                  children: [
                    _buildSummaryCard(context, title: 'Transaksi Hari Ini', value: '$_todayCount', icon: Icons.receipt_long, color: Colors.orange),
                    const SizedBox(width: 12),
                    _buildSummaryCard(context, title: 'Total Omzet', value: currencyFormat.format(_todayOmzet), icon: Icons.payments, color: Colors.green),
                  ],
                ),
              
              const SizedBox(height: 32),
              const Text('Menu Cepat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildQuickMenu(
                title: 'Buka Kasir (POS)',
                subtitle: 'Mulai transaksi baru',
                icon: Icons.shopping_cart,
                color: Colors.blue,
                onTap: () => widget.onNavigate(1),
              ),
              const Divider(),
              if (widget.user['usr_role_id'] == 1) ...[
                _buildQuickMenu(
                  title: 'Manajemen Produk',
                  subtitle: 'Tambah atau ubah data produk',
                  icon: Icons.inventory,
                  color: Colors.purple,
                  onTap: () => widget.onNavigate(2),
                ),
                const Divider(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMenu({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  Widget _buildSummaryCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color, bool isFullWidth = false}) {
    Widget card = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    return isFullWidth ? SizedBox(width: double.infinity, child: card) : Expanded(child: card);
  }
}
