import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';

class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key});

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> {
  List<Map<String, dynamic>> _logs = [];
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.start);
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.end);
    
    final data = await DatabaseHelper.instance.getPosLogs(
      startDate: startDate, 
      endDate: endDate
    );
    
    setState(() {
      _logs = data;
      _isLoading = false;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Periode Log:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('Filter Tanggal'),
                ),
              ],
            ),
          ),
          
          // Log List
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _logs.isEmpty 
              ? const Center(child: Text('Tidak ada aktivitas log pada periode ini.'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final bool isDelete = log['log_action'] == 'DELETE';
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isDelete ? Colors.red[100] : Colors.orange[100],
                          child: Icon(
                            isDelete ? Icons.delete_forever : Icons.remove_circle,
                            color: isDelete ? Colors.red : Colors.orange,
                          ),
                        ),
                        title: Text('${log['prd_name']} (${log['log_prd_sku']})', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aksi: ${log['log_action']} | Oleh: ${log['usr_name']}'),
                            Text('Qty: ${log['log_old_qty']} -> ${log['log_new_qty']}'),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(log['log_timestamp'])),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        isThreeLine: true,
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
