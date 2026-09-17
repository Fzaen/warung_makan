import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class PrintService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // Fungsi internal untuk membuat dokumen PDF struk yang SUPER HEMAT KERTAS
  Future<pw.Document> generatePdfDoc({
    required Map<String, dynamic> saleData,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> settings,
  }) async {
    final doc = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final bool isReprint = saleData['is_reprint'] ?? false;

    doc.addPage(
      pw.Page(
        // Ukuran kertas 58mm (lebih umum untuk thermal hemat) atau tetap 72mm dengan konten rapat
        pageFormat: const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 1 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Rapat
              pw.Center(
                child: pw.Text(settings['set_warung_name'] ?? "WARUNG MAKAN", 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              ),
              pw.Center(child: pw.Text(settings['set_address'] ?? "", 
                style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center)),
              
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - -", style: const pw.TextStyle(fontSize: 7)),
              
              // Info Transaksi Satu Baris (Hemat Ruang)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Inv: ${saleData['sls_invoice_number'].toString().split('-').last} (${saleData['usr_username'] ?? 'User'})", style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(saleData['sls_transaction_date'])), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - -", style: const pw.TextStyle(fontSize: 7)),

              // List Items Rapat
              pw.ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("${item['itm_quantity']}x", style: const pw.TextStyle(fontSize: 7)),
                        pw.SizedBox(width: 4),
                        pw.Expanded(
                          child: pw.Text(item['prd_name'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
                        ),
                        pw.Text(currencyFormat.format(item['itm_subtotal']), style: const pw.TextStyle(fontSize: 7)),
                      ],
                    ),
                  );
                },
              ),

              pw.Text("- - - - - - - - - - - - - - - - - - - - - - -", style: const pw.TextStyle(fontSize: 7)),
              
              // Ringkasan Pembayaran Rapat
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  pw.Text(currencyFormat.format(saleData['sls_grand_total']), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Bayar", style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(currencyFormat.format(saleData['sls_paid_amount']), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Kembali", style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(currencyFormat.format(saleData['sls_change_amount']), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - -", style: const pw.TextStyle(fontSize: 7)),
              if (isReprint)
                pw.Center(child: pw.Text("*** REPRINT STRUK ***", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.SizedBox(height: 2), 
            ],
          );
        },
      ),
    );
    return doc;
  }

  // 1. LIHAT STRUK (Preview & Share)
  Future<void> viewReceipt({
    required Map<String, dynamic> saleData,
    required List<Map<String, dynamic>> items,
  }) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Struk-${saleData['sls_invoice_number']}',
    );
  }

  // 2. CETAK LANGSUNG
  Future<void> printDirect({
    required Map<String, dynamic> saleData,
    required List<Map<String, dynamic>> items,
  }) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final defaultPrinterName = settings['set_default_printer'];

    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);

    if (defaultPrinterName != null) {
      final printers = await Printing.listPrinters();
      final printer = printers.firstWhere(
        (p) => p.name == defaultPrinterName,
        orElse: () => printers.first,
      );

      await Printing.directPrintPdf(
        printer: printer,
        onLayout: (PdfPageFormat format) async => doc.save(),
      );
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Struk-${saleData['sls_invoice_number']}',
      );
    }
  }

  // 3. SHARE STRUK
  Future<void> shareReceipt({
    required Map<String, dynamic> saleData,
    required List<Map<String, dynamic>> items,
  }) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);
    final pdfBytes = await doc.save();

    await Share.shareXFiles(
      [XFile.fromData(pdfBytes, name: 'Struk-${saleData['sls_invoice_number']}.pdf', mimeType: 'application/pdf')],
      text: 'Struk Belanja ${settings['set_warung_name']} - ${saleData['sls_invoice_number']}',
    );
  }
}
