import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../../database_helper.dart';

class ItemSalesReportPage extends StatefulWidget {
  final String groupingType; 
  const ItemSalesReportPage({super.key, required this.groupingType});

  @override
  State<ItemSalesReportPage> createState() => _ItemSalesReportPageState();
}

class _ItemSalesReportPageState extends State<ItemSalesReportPage> {
  List<Map<String, dynamic>> _data = [];
  DateTimeRange _selectedDateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  bool _isLoading = true;
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  int? _sortColumnIndex;
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.start);
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.end);
    
    List<Map<String, dynamic>> reportData;
    if (widget.groupingType == 'category') {
      reportData = await DatabaseHelper.instance.getSalesByCategoryReport(startDate: startDate, endDate: endDate);
    } else if (widget.groupingType == 'subcategory') {
      reportData = await DatabaseHelper.instance.getSalesBySubCategoryReport(startDate: startDate, endDate: endDate);
    } else {
      reportData = await DatabaseHelper.instance.getSalesByItemReport(startDate: startDate, endDate: endDate);
    }
    
    setState(() {
      _data = List<Map<String, dynamic>>.from(reportData);
      _isLoading = false;
      _sortColumnIndex = (widget.groupingType == 'item') ? 3 : (widget.groupingType == 'category' ? 1 : 2);
      _isAscending = false;
      _onSort(_sortColumnIndex!, _isAscending);
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _isAscending = ascending;
      _data.sort((a, b) {
        dynamic aV, bV;
        if (widget.groupingType == 'item') {
          switch (columnIndex) {
            case 0: aV = a['prd_name']; bV = b['prd_name']; break;
            case 1: aV = a['cat_name']; bV = b['cat_name']; break;
            case 2: aV = a['cat_subname']; bV = b['cat_subname']; break;
            case 3: aV = a['total_qty']; bV = b['total_qty']; break;
            case 4: aV = a['total_trx']; bV = b['total_trx']; break;
            case 5: aV = a['total_sales']; bV = b['total_sales']; break;
            case 6: aV = a['total_profit']; bV = b['total_profit']; break;
          }
        } else if (widget.groupingType == 'category') {
          switch (columnIndex) {
            case 0: aV = a['cat_name']; bV = b['cat_name']; break;
            case 1: aV = a['total_qty']; bV = b['total_qty']; break;
            case 2: aV = a['total_trx']; bV = b['total_trx']; break;
            case 3: aV = a['total_sales']; bV = b['total_sales']; break;
            case 4: aV = a['total_profit']; bV = b['total_profit']; break;
          }
        } else {
          switch (columnIndex) {
            case 0: aV = a['cat_name']; bV = b['cat_name']; break;
            case 1: aV = a['cat_subname']; bV = b['cat_subname']; break;
            case 2: aV = a['total_qty']; bV = b['total_qty']; break;
            case 3: aV = a['total_trx']; bV = b['total_trx']; break;
            case 4: aV = a['total_sales']; bV = b['total_sales']; break;
            case 5: aV = a['total_profit']; bV = b['total_profit']; break;
          }
        }
        return ascending ? Comparable.compare(aV ?? '', bV ?? '') : Comparable.compare(bV ?? '', aV ?? '');
      });
    });
  }

  Future<void> _exportToExcel() async {
    setState(() => _isLoading = true);
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];
      List<dynamic> headers = (widget.groupingType == 'item') ? ['SKU', 'Produk', 'Kategori', 'Sub-Kategori', 'Qty', 'Trx', 'HPP Total', 'Jual Total', 'Margin'] : (widget.groupingType == 'category' ? ['Kategori', 'Qty', 'Trx', 'HPP Total', 'Jual Total', 'Margin'] : ['Kategori', 'Sub-Kategori', 'Qty', 'Trx', 'HPP Total', 'Jual Total', 'Margin']);
      sheetObject.appendRow(headers);
      for (var row in _data) {
        List<dynamic> dataRow = (widget.groupingType == 'item') ? [row['itm_sku'] ?? '', row['prd_name'] ?? '', row['cat_name'] ?? '', row['cat_subname'] ?? ''] : (widget.groupingType == 'category' ? [row['cat_name'] ?? ''] : [row['cat_name'] ?? '', row['cat_subname'] ?? '']);
        dataRow.addAll([row['total_qty'], row['total_trx'], row['total_cost'], row['total_sales'], row['total_profit']]);
        sheetObject.appendRow(dataRow);
      }
      var fileBytes = excel.save();
      if (fileBytes != null) {
        final String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
        final String fileName = "Laporan_${widget.groupingType}_$timestamp.xlsx";
        final String filePath = await DatabaseHelper.instance.getExportPath(fileName);
        final File file = File(filePath);
        await file.writeAsBytes(fileBytes, flush: true);
        await Future.delayed(const Duration(milliseconds: 500));
        await Share.shareXFiles([XFile(file.path, name: fileName)], text: 'Laporan Penjualan Warung Makan');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.groupingType == 'category' ? "Per Kategori" : (widget.groupingType == 'subcategory' ? "Per Sub-Kategori" : "Per Item");
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
              IconButton(onPressed: _exportToExcel, icon: const Icon(Icons.file_download, color: Colors.green)),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () async { final picked = await showDateRangePicker(context: context, initialDateRange: _selectedDateRange, firstDate: DateTime(2023), lastDate: DateTime.now()); if (picked != null) { setState(() => _selectedDateRange = picked); _loadReport(); } }, child: Text("${DateFormat('dd/MM').format(_selectedDateRange.start)}-${DateFormat('dd/MM').format(_selectedDateRange.end)}", style: const TextStyle(fontSize: 11))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _data.isEmpty ? const Center(child: Text('Tidak ada data.')) :
            InteractiveViewer(
              constrained: false,
              scaleEnabled: false,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _isAscending,
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                columnSpacing: 30,
                horizontalMargin: 15,
                columns: _buildColumns(),
                rows: _data.map((row) => DataRow(cells: _buildCells(row))).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (widget.groupingType == 'item') {
      return [
        DataColumn(label: const SizedBox(width: 140, child: Text('Produk')), onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Kategori'), onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Sub'), onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Qty'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Trx'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Jual'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Margin'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
      ];
    } else if (widget.groupingType == 'category') {
      return [
        DataColumn(label: const SizedBox(width: 140, child: Text('Kategori')), onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Qty'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Trx'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Jual'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Margin'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
      ];
    } else { 
      return [
        DataColumn(label: const SizedBox(width: 120, child: Text('Kategori')), onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const SizedBox(width: 120, child: Text('Sub')), onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Qty'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Trx'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Jual'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
        DataColumn(label: const Text('Margin'), numeric: true, onSort: (idx, asc) => _onSort(idx, asc)),
      ];
    }
  }

  List<DataCell> _buildCells(Map<String, dynamic> row) {
    if (widget.groupingType == 'item') {
      return [DataCell(Text(row['prd_name'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))), DataCell(Text(row['cat_name'] ?? '', style: const TextStyle(fontSize: 11))), DataCell(Text(row['cat_subname'] ?? '', style: const TextStyle(fontSize: 11))), DataCell(Text('${row['total_qty']}', style: const TextStyle(fontSize: 11))), DataCell(Text('${row['total_trx']}', style: const TextStyle(fontSize: 11))), DataCell(Text(_currencyFormat.format(row['total_sales']), style: const TextStyle(fontSize: 11))), DataCell(Text(_currencyFormat.format(row['total_profit']), style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)))];
    } else if (widget.groupingType == 'category') {
      return [DataCell(Text(row['cat_name'] ?? '', style: const TextStyle(fontSize: 11))), DataCell(Text('${row['total_qty']}', style: const TextStyle(fontSize: 11))), DataCell(Text('${row['total_trx']}', style: const TextStyle(fontSize: 11))), DataCell(Text(_currencyFormat.format(row['total_sales']), style: const TextStyle(fontSize: 11))), DataCell(Text(_currencyFormat.format(row['total_profit']), style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)))];
    } else {
      return [DataCell(Text(row['cat_name'] ?? '', style: const TextStyle(fontSize: 11))), DataCell(Text(row['cat_subname'] ?? '', style: const TextStyle(fontSize: 11))), DataCell(Text('${row['total_qty']}', style: const TextStyle(fontSize: 11))), DataCell(Text('${row['total_trx']}', style: const TextStyle(fontSize: 11))), DataCell(Text(_currencyFormat.format(row['total_sales']), style: const TextStyle(fontSize: 11))), DataCell(Text(_currencyFormat.format(row['total_profit']), style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)))];
    }
  }
}
