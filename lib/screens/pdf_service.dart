// lib/screens/pdf_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
class PdfService {
  static Future<void> generateMonthlyReport({
    required DateTime month,
    required List<Sale> sales,
    required Map<String, double> dailyMap,
    required Map<String, double> productMap,
    required double totalProfit,
  }) async {
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    final fmtInt = NumberFormat('#,##0', 'en_IN');
    final monthLabel = DateFormat('MMMM yyyy').format(month);

    final pdf = pw.Document();

    // Color palette
    const headerBlue = PdfColor.fromInt(0xFF1F4E79);
    const lightBlue  = PdfColor.fromInt(0xFFE6F1FB);
    const green      = PdfColor.fromInt(0xFF1A6B2A);
    const lightGreen = PdfColor.fromInt(0xFFC6EFCE);
    const grey       = PdfColor.fromInt(0xFF888888);
    const lightGrey  = PdfColor.fromInt(0xFFF5F6FA);

    // Sort sales by date
    final sorted = [...sales]..sort((a, b) => a.date.compareTo(b.date));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => pw.Column(children: [
        pw.Row(children: [
          pw.Expanded(child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PROFIT STATEMENT',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold,
                      color: headerBlue)),
              pw.Text(monthLabel,
                  style: pw.TextStyle(fontSize: 13, color: grey)),
            ],
          )),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: pw.BoxDecoration(
              color: totalProfit >= 30000 ? lightGreen : lightBlue,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Total Profit',
                  style: pw.TextStyle(fontSize: 10, color: grey)),
              pw.Text('Rs ${fmtInt.format(totalProfit)}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold,
                      color: totalProfit >= 30000 ? green : headerBlue)),
            ]),
          ),
        ]),
        pw.SizedBox(height: 8),
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
      ]),
      build: (ctx) => [
        // Summary row
        pw.Row(children: [
          _pdfStat('Sales days', '${dailyMap.length}', lightBlue, headerBlue),
          pw.SizedBox(width: 8),
          _pdfStat('Total sales', '${sales.length}', lightBlue, headerBlue),
          pw.SizedBox(width: 8),
          _pdfStat('Avg / day',
              dailyMap.isEmpty ? 'Rs 0'
                  : 'Rs ${fmtInt.format(totalProfit / dailyMap.length)}',
              lightBlue, headerBlue),
          pw.SizedBox(width: 8),
          _pdfStat('Target gap',
              totalProfit >= 30000
                  ? '+Rs ${fmtInt.format(totalProfit - 30000)}'
                  : '-Rs ${fmtInt.format(30000 - totalProfit)}',
              totalProfit >= 30000 ? lightGreen : const PdfColor.fromInt(0xFFFFCCCC),
              totalProfit >= 30000 ? green : const PdfColor.fromInt(0xFFBB3333)),
        ]),
        pw.SizedBox(height: 16),

        // Product breakdown
        if (productMap.isNotEmpty) ...[
          _pdfSectionTitle('Profit by Product', headerBlue),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: headerBlue),
                children: [
                  _pdfHeaderCell('Product'),
                  _pdfHeaderCell('Profit (Rs)', align: pw.Alignment.centerRight),
                  _pdfHeaderCell('Share %', align: pw.Alignment.centerRight),
                ],
              ),
              ...(() {
                final entries = productMap.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                return entries.asMap().entries.map((e) {
                  final i = e.key; final entry = e.value;
                  final parts = entry.key.split('|');
                  final name = parts.length > 1 ? parts[1] : entry.key;
                  final pct = totalProfit > 0 ? (entry.value / totalProfit * 100) : 0.0;
                  final bg = i % 2 == 0 ? lightGrey : PdfColors.white;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: bg),
                    children: [
                      _pdfCell(name),
                      _pdfCell('Rs ${fmt.format(entry.value)}',
                          align: pw.Alignment.centerRight,
                          bold: true, color: green),
                      _pdfCell('${pct.toStringAsFixed(1)}%',
                          align: pw.Alignment.centerRight),
                    ],
                  );
                }).toList();
              })(),
            ],
          ),
          pw.SizedBox(height: 16),
        ],

        // Sales table
        _pdfSectionTitle('All Sales — $monthLabel', headerBlue),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(3),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: headerBlue),
              children: [
                _pdfHeaderCell('Date'),
                _pdfHeaderCell('Product'),
                _pdfHeaderCell('Qty', align: pw.Alignment.centerRight),
                _pdfHeaderCell('Profit (Rs)', align: pw.Alignment.centerRight),
              ],
            ),
            ...sorted.asMap().entries.map((e) {
              final i = e.key; final s = e.value;
              final bg = i % 2 == 0 ? lightGrey : PdfColors.white;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _pdfCell(DateFormat('dd/MM/yyyy').format(s.date)),
                  _pdfCell(s.productName),
                  _pdfCell(
                    '${s.qty % 1 == 0 ? s.qty.toInt() : s.qty.toStringAsFixed(1)}',
                    align: pw.Alignment.centerRight),
                  _pdfCell('Rs ${fmt.format(s.profit)}',
                      align: pw.Alignment.centerRight,
                      bold: true, color: green),
                ],
              );
            }),
            // Total row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: lightBlue),
              children: [
                _pdfCell('Total', bold: true, colspan: 3),
                _pdfCell('', bold: true),
                _pdfCell('', bold: true),
                _pdfCell('Rs ${fmt.format(totalProfit)}',
                    align: pw.Alignment.centerRight, bold: true, color: green),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // Footer
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 6),
        pw.Row(children: [
          pw.Expanded(child: pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: grey))),
          pw.Text('Profit Tracker App — Personal Use',
              style: pw.TextStyle(fontSize: 9, color: grey)),
        ]),
      ],
    ));

    // Save to Downloads
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) dir = await getExternalStorageDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final filename = 'profit_${DateFormat('MMM_yyyy').format(month)}'
        '_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = '${dir!.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    // Also share/print it
    await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
  }

  static pw.Widget _pdfStat(String label, String value,
      PdfColor bg, PdfColor color) {
    return pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.SizedBox(height: 3),
        pw.Text(value, style: pw.TextStyle(fontSize: 13,
            fontWeight: pw.FontWeight.bold, color: color)),
      ]),
    ));
  }

  static pw.Widget _pdfSectionTitle(String text, PdfColor color) =>
      pw.Text(text, style: pw.TextStyle(fontSize: 13,
          fontWeight: pw.FontWeight.bold, color: color));

  static pw.Widget _pdfHeaderCell(String text,
      {pw.Alignment align = pw.Alignment.centerLeft}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: pw.Align(alignment: align,
          child: pw.Text(text, style: pw.TextStyle(
              fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
      );

  static pw.Widget _pdfCell(String text,
      {pw.Alignment align = pw.Alignment.centerLeft,
      bool bold = false, PdfColor? color, int colspan = 1}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Align(alignment: align,
          child: pw.Text(text, style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color ?? PdfColors.black))),
      );
}