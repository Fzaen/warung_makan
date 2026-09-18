import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../database_helper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  List<Printer> _availablePrinters = [];
  String? _selectedPrinterName;
  int _selectedPaperSize = 80;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPrinters();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    setState(() {
      _nameController.text = settings['set_warung_name'] ?? 'WARUNG MAKAN';
      _addressController.text = settings['set_address'] ?? '';
      _phoneController.text = settings['set_phone'] ?? '';
      _selectedPrinterName = settings['set_default_printer'];
      _selectedPaperSize = settings['set_paper_size'] ?? 80;
      _isLoading = false;
    });
  }

  Future<void> _loadPrinters() async {
    final printers = await Printing.listPrinters();
    setState(() { _availablePrinters = printers; });
  }

  Future<void> _saveSettings() async {
    await DatabaseHelper.instance.updateSettings({
      'set_warung_name': _nameController.text.toUpperCase(),
      'set_address': _addressController.text,
      'set_phone': _phoneController.text,
      'set_default_printer': _selectedPrinterName,
      'set_paper_size': _selectedPaperSize,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan berhasil disimpan')));
  }

  Future<void> _handleBackup() async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        await Share.shareXFiles([XFile(dbPath, name: 'Backup_WarungMakan_$timestamp.db')], text: 'Cadangan Database');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal backup: $e')));
    }
  }

  Future<void> _handleRestore() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        bool confirm = await showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Pulihkan Data?'), content: const Text('Data saat ini akan ditimpa. Lanjutkan?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: const Text('YA, PULIHKAN'))])) ?? false;
        if (confirm) {
          setState(() => _isLoading = true);
          await DatabaseHelper.instance.restoreDatabase(result.files.single.path!);
          setState(() => _isLoading = false);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil! Silakan restart aplikasi.')));
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal restore: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('INFORMASI WARUNG', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 12),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nama Warung', border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront, size: 20))),
            const SizedBox(height: 10),
            TextField(controller: _addressController, decoration: const InputDecoration(labelText: 'Alamat', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on_outlined, size: 20))),
            const SizedBox(height: 10),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'No. Telp', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone, size: 20))),
            const SizedBox(height: 24),
            
            const Text('PENGATURAN PRINTER', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _availablePrinters.any((p) => p.name == _selectedPrinterName) ? _selectedPrinterName : null,
              decoration: const InputDecoration(labelText: 'Pilih Printer', border: OutlineInputBorder(), prefixIcon: Icon(Icons.print, size: 20)),
              items: _availablePrinters.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (val) => setState(() => _selectedPrinterName = val),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: _selectedPaperSize,
              decoration: const InputDecoration(labelText: 'Ukuran Kertas', border: OutlineInputBorder(), prefixIcon: Icon(Icons.straighten, size: 20)),
              items: const [
                DropdownMenuItem(value: 58, child: Text('58 mm (Kecil)')),
                DropdownMenuItem(value: 80, child: Text('80 mm (Besar)')),
              ],
              onChanged: (val) => setState(() => _selectedPaperSize = val!),
            ),
            const SizedBox(height: 24),

            const Text('KEAMANAN DATA', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _handleBackup, icon: const Icon(Icons.cloud_upload, size: 18), label: const Text('BACKUP'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: _handleRestore, icon: const Icon(Icons.cloud_download, size: 18), label: const Text('RESTORE'))),
            ]),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, height: 45, child: ElevatedButton(onPressed: _saveSettings, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('SIMPAN SEMUA PENGATURAN'))),
          ],
        ),
      ),
    );
  }
}
