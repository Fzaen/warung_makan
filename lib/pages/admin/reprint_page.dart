import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';
import '../../print_service.dart';

class ReprintPage extends StatefulWidget {
  const ReprintPage({super.key});

  @override
  State<ReprintPage> createState() => _ReprintPageState();
}

class _ReprintPageState extends State<ReprintPage> {
  List<Map<String, dynamic>> _sales = [];
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  bool _isLoading = false;
  final PrintService _printService = PrintService();
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.start);
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.end);
    
    final data = await DatabaseHelper.instance.getSalesHistory(
      startDate: startDate, 
      endDate: endDate
    );
    
    setState(() {
      _sales = data;
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
      _fetchSales();
    }
  }

  void _handleReprint(String invoiceNumber) async {
    final data = await DatabaseHelper.instance.getSaleByInvoice(invoiceNumber);
    if (data != null) {
      // Tambahkan flag reprint ke data sebelum dicetak
      Map<String, dynamic> sale = Map.from(data['sale']);
      sale['is_reprint'] = true; 

      await _printService.viewReceipt(
        saleData: sale,
        items: List<Map<String, dynamic>>.from(data['items']),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Riwayat Trx (${_sales.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(DateFormat('dd/MM/yy').format(_selectedDateRange.start)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _sales.isEmpty 
              ? const Center(child: Text('Tidak ada transaksi.'))
              : ListView.builder(
                  itemCount: _sales.length,
                  itemBuilder: (context, index) {
                    final s = _sales[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(s['sls_invoice_number'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${DateFormat('HH:mm').format(DateTime.parse(s['sls_transaction_date']))} | ${s['usr_username']}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_currencyFormat.format(s['sls_grand_total']), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 25,
                              child: ElevatedButton(
                                onPressed: () => _handleReprint(s['sls_invoice_number']),
                                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), fontSize: 10),
                                child: const Text('REPRINT'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
