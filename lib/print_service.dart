import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'database_helper.dart';

class PrintService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<pw.Document> generatePdfDoc({
    required Map<String, dynamic> saleData,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> settings,
  }) async {
    final doc = pw.Document();
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);
    final bool isReprint = saleData['is_reprint'] ?? false;
    final int paperSizeMm = settings['set_paper_size'] ?? 80;
    final double marginMm = (settings['set_margin'] ?? 5.0).toDouble();
    final double pageWidth = paperSizeMm * PdfPageFormat.mm;
    final double margin = marginMm * PdfPageFormat.mm;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, double.infinity, marginAll: margin),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(settings['set_warung_name'] ?? "WARUNG MAKAN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperSizeMm == 80 ? 11 : 9))),
              pw.Center(child: pw.Text(settings['set_address'] ?? "", style: pw.TextStyle(fontSize: paperSizeMm == 80 ? 8 : 7), textAlign: pw.TextAlign.center)),
              pw.Center(child: pw.Text("Telp: ${settings['set_phone'] ?? ""}", style: pw.TextStyle(fontSize: paperSizeMm == 80 ? 8 : 7))),
              pw.SizedBox(height: 3),
              pw.Text("--------------------------------------------------------------------------------", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Inv: ${saleData['sls_invoice_number'].toString().split('-').last} (${saleData['usr_username'] ?? 'User'})", style: const pw.TextStyle(fontSize: 7)),
                  pw.Text(DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(saleData['sls_transaction_date'])), style: const pw.TextStyle(fontSize: 7)),
                ],
              ),
              pw.Text("--------------------------------------------------------------------------------", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              pw.ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(child: pw.Text("${item['itm_quantity']}x ${item['prd_name']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperSizeMm == 80 ? 8 : 7))),
                        pw.Text(currencyFormat.format(item['itm_subtotal']), style: pw.TextStyle(fontSize: paperSizeMm == 80 ? 8 : 7)),
                      ],
                    ),
                  );
                },
              ),
              pw.Text("--------------------------------------------------------------------------------", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperSizeMm == 80 ? 10 : 8)),
                  pw.Text("Rp ${currencyFormat.format(saleData['sls_grand_total'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperSizeMm == 80 ? 10 : 8)),
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
              if (isReprint) ...[
                pw.SizedBox(height: 5),
                pw.Center(child: pw.Text("*** REPRINT STRUK ***", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              ],
              pw.SizedBox(height: 2), 
            ],
          );
        },
      ),
    );
    return doc;
  }

  Future<void> viewReceipt({required Map<String, dynamic> saleData, required List<Map<String, dynamic>> items}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Struk-${saleData['sls_invoice_number']}');
  }

  Future<void> printDirect({required Map<String, dynamic> saleData, required List<Map<String, dynamic>> items}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final defaultPrinterName = settings['set_default_printer'];
    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);

    if (defaultPrinterName != null) {
      final printers = await Printing.listPrinters();
      try {
        final printer = printers.firstWhere((p) => p.name == defaultPrinterName);
        await Printing.directPrintPdf(printer: printer, onLayout: (PdfPageFormat format) async => doc.save());
      } catch (e) {
        await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
      }
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
    }
  }

  Future<void> shareReceipt({required Map<String, dynamic> saleData, required List<Map<String, dynamic>> items}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);
    final pdfBytes = await doc.save();
    
    // Simpan ke folder exports yang dikelola (dihapus tiap app open)
    final cleanInvoice = saleData['sls_invoice_number'].toString().replaceAll(RegExp(r'[^\w\-]'), '_');
    final String filePath = await DatabaseHelper.instance.getExportPath('Struk_$cleanInvoice.pdf');
    final File file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Struk Belanja ${settings['set_warung_name']}');
  }
}
