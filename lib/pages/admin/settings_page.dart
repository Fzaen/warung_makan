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
      _isLoading = false;
    });
  }

  Future<void> _loadPrinters() async {
    final printers = await Printing.listPrinters();
    setState(() {
      _availablePrinters = printers;
    });
  }

  Future<void> _saveSettings() async {
    await DatabaseHelper.instance.updateSettings({
      'set_warung_name': _nameController.text.toUpperCase(),
      'set_address': _addressController.text,
      'set_phone': _phoneController.text,
      'set_default_printer': _selectedPrinterName,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan berhasil disimpan')),
    );
  }

  // FUNGSI BACKUP (Export ke File/Share)
  Future<void> _handleBackup() async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      final dbFile = File(dbPath);

      if (await dbFile.exists()) {
        final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final String fileName = 'Backup_WarungMakan_$timestamp.db';

        // Share file agar user bisa simpan ke WA, Drive, atau Folder lokal
        await Share.shareXFiles(
          [XFile(dbPath, name: fileName)],
          text: 'Cadangan Database Warung Makan - $timestamp',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal melakukan backup: $e')),
      );
    }
  }

  // FUNGSI RESTORE (Import dari File)
  Future<void> _handleRestore() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Database SQLite biasanya .db
      );

      if (result != null && result.files.single.path != null) {
        String path = result.files.single.path!;
        
        // Konfirmasi sebelum menimpa data
        if (!mounted) return;
        bool confirm = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pulihkan Data?'),
            content: const Text('PERINGATAN: Semua data saat ini akan dihapus dan diganti dengan data dari file cadangan. Lanjutkan?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('BATAL')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true), 
                child: const Text('YA, PULIHKAN', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;

        if (confirm) {
          setState(() => _isLoading = true);
          await DatabaseHelper.instance.restoreDatabase(path);
          setState(() => _isLoading = false);
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Data berhasil dipulihkan! Silakan restart aplikasi.')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memulihkan data: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('INFORMASI WARUNG', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Warung',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Lengkap',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'No. Telp / WhatsApp',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('SIMPAN INFORMASI'),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text('PENGATURAN PRINTER', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _availablePrinters.any((p) => p.name == _selectedPrinterName) 
                      ? _selectedPrinterName 
                      : null,
                    decoration: const InputDecoration(
                      labelText: 'Default Printer',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.print),
                    ),
                    items: _availablePrinters.map((printer) {
                      return DropdownMenuItem<String>(
                        value: printer.name,
                        child: Text(printer.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedPrinterName = val);
                      _saveSettings(); // Langsung simpan saat ganti printer
                    },
                  ),

                  const SizedBox(height: 32),
                  const Text('KEAMANAN DATA (BACKUP)', 
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleBackup,
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('BACKUP'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _handleRestore,
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('RESTORE'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('* Backup akan mengirimkan file database ke WhatsApp/Email Anda sebagai cadangan.', 
                    style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
    );
  }
}
