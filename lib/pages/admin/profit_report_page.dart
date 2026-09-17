import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';

class ProfitReportPage extends StatefulWidget {
  const ProfitReportPage({super.key});

  @override
  State<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends State<ProfitReportPage> {
  List<Map<String, dynamic>> _reportData = [];
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
  bool _isLoading = false;
  
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  Future<void> _fetchReport() async {
    setState(() => _isLoading = true);
    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.start);
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.end);
    
    final data = await DatabaseHelper.instance.getProfitReport(
      startDate: startDate, 
      endDate: endDate
    );
    
    setState(() {
      _reportData = data;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalRevenue = _reportData.fold(0, (sum, item) => sum + (item['total_revenue'] as num));
    double totalCost = _reportData.fold(0, (sum, item) => sum + (item['total_cost'] as num));
    double totalProfit = totalRevenue - totalCost;

    return Scaffold(
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periode Laporan:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Ubah Tanggal', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                _buildSummaryBox('Omzet', totalRevenue, Colors.blue),
                const SizedBox(width: 8),
                _buildSummaryBox('Laba Bersih', totalProfit, Colors.green),
              ],
            ),
          ),

          // Detailed Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(child: Text('Trx', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Omzet', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 2, child: Text('Laba', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),

          // Log List
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _reportData.isEmpty 
              ? const Center(child: Text('Tidak ada data transaksi.'))
              : ListView.builder(
                  itemCount: _reportData.length,
                  itemBuilder: (context, index) {
                    final row = _reportData[index];
                    double revenue = (row['total_revenue'] as num).toDouble();
                    double cost = (row['total_cost'] as num).toDouble();
                    double profit = revenue - cost;
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2, 
                            child: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(row['date'])), style: const TextStyle(fontSize: 12))
                          ),
                          Expanded(
                            child: Text('${row['total_invoices']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))
                          ),
                          Expanded(
                            flex: 2, 
                            child: Text(_currencyFormat.format(revenue), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))
                          ),
                          Expanded(
                            flex: 2, 
                            child: Text(_currencyFormat.format(profit), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green))
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(String title, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(_currencyFormat.format(value), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
