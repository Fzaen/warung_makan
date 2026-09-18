import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
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
    
    // Ambil setting ukuran kertas
    final int paperWidthMm = settings['set_paper_size'] ?? 80;
    
    doc.addPage(
      pw.Page(
        // Responsif: Lebar PDF mengikuti setting (58mm atau 80mm)
        pageFormat: PdfPageFormat(paperWidthMm * PdfPageFormat.mm, double.infinity, marginAll: 1 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text(settings['set_warung_name'] ?? "WARUNG MAKAN", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperWidthMm == 80 ? 12 : 10))),
              pw.Center(child: pw.Text(settings['set_address'] ?? "", style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7), textAlign: pw.TextAlign.center)),
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Inv: ${saleData['sls_invoice_number'].toString().split('-').last} (${saleData['usr_username'] ?? 'User'})", style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                  pw.Text(DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(saleData['sls_transaction_date'])), style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                ],
              ),
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              pw.ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text("${item['itm_quantity']}x ${item['prd_name']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperWidthMm == 80 ? 9 : 7)),
                        ),
                        pw.Text(currencyFormat.format(item['itm_subtotal']), style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                      ],
                    ),
                  );
                },
              ),
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperWidthMm == 80 ? 11 : 9)),
                  pw.Text("Rp ${currencyFormat.format(saleData['sls_grand_total'])}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: paperWidthMm == 80 ? 11 : 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Bayar", style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                  pw.Text(currencyFormat.format(saleData['sls_paid_amount']), style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Kembali", style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                  pw.Text(currencyFormat.format(saleData['sls_change_amount']), style: pw.TextStyle(fontSize: paperWidthMm == 80 ? 9 : 7)),
                ],
              ),
              pw.Text("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -", maxLines: 1, style: const pw.TextStyle(fontSize: 7)),
              if (isReprint)
                pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text("*** REPRINT STRUK ***", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)))),
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
      final printer = printers.firstWhere((p) => p.name == defaultPrinterName, orElse: () => printers.first);
      await Printing.directPrintPdf(printer: printer, onLayout: (PdfPageFormat format) async => doc.save());
    } else {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save(), name: 'Struk-${saleData['sls_invoice_number']}');
    }
  }

  Future<void> shareReceipt({required Map<String, dynamic> saleData, required List<Map<String, dynamic>> items}) async {
    final settings = await DatabaseHelper.instance.getSettings();
    final doc = await generatePdfDoc(saleData: saleData, items: items, settings: settings);
    final pdfBytes = await doc.save();
    final tempDir = await getTemporaryDirectory();
    final cleanInvoice = saleData['sls_invoice_number'].toString().replaceAll(RegExp(r'[^\w\-]'), '_');
    final fileName = 'Struk-$cleanInvoice.pdf';
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(tempFile.path, name: fileName, mimeType: 'application/pdf')], text: 'Struk Belanja ${settings['set_warung_name']}');
  }
}
