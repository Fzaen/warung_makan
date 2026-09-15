import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  final Map<String, dynamic> user;
  const HomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Format IDR: Titik sebagai pemisah ribuan, tanpa desimal
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selamat Datang,',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            Text(
              user['usr_name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(height: 30),

            Row(
              children: [
                _buildSummaryCard(
                  context,
                  title: 'Transaksi Hari Ini',
                  value: '0',
                  icon: Icons.receipt_long,
                  color: Colors.orange,
                ),
                const SizedBox(width: 15),
                _buildSummaryCard(
                  context,
                  title: 'Total Omzet',
                  value: currencyFormat.format(0),
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
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.shopping_cart, color: Colors.white),
              ),
              title: const Text('Buka Kasir (POS)'),
              subtitle: const Text('Mulai transaksi baru'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {},
            ),
            const Divider(),
            if (user['usr_role_id'] == 1) ...[
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.inventory, color: Colors.white),
                ),
                title: const Text('Manajemen Produk'),
                subtitle: const Text('Tambah atau ubah data produk'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {},
              ),
              const Divider(),
            ],
          ],
        ),
      ),
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
              Icon(icon, color: color, size: 30),
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
