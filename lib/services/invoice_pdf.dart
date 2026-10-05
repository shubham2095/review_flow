import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

String _s(dynamic v) => v?.toString() ?? '';

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(_s(v)) ?? 0;
}

String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

/// Builds a tax invoice PDF from the invoice detail response and shares it.
/// The PDF uses "Rs." because the default PDF font has no rupee glyph.
Future<void> shareInvoicePdf(Map<String, dynamic> wrapper) async {
  final inv = (wrapper['invoice'] as Map<String, dynamic>?) ?? {};
  final settings = (wrapper['settings'] as Map<String, dynamic>?) ?? {};
  final client = (inv['client'] as Map<String, dynamic>?) ?? {};
  final items = ((inv['items'] as List?) ?? []).cast<Map<String, dynamic>>();

  final doc = pw.Document();
  final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _s(settings['company_name']).isEmpty ? 'Your Business' : _s(settings['company_name']),
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                if (_s(settings['address']).isNotEmpty) pw.Text(_s(settings['address'])),
                if (_s(settings['phone']).isNotEmpty) pw.Text('Phone: ${_s(settings['phone'])}'),
                if (_s(settings['email']).isNotEmpty) pw.Text('Email: ${_s(settings['email'])}'),
                if (_s(settings['gstin']).isNotEmpty) pw.Text('GSTIN: ${_s(settings['gstin'])}'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.Text(_s(inv['invoice_number'])),
                pw.Text('Issued: ${_s(inv['issue_date']).split('T').first}'),
                if (_s(inv['due_date']).isNotEmpty) pw.Text('Due: ${_s(inv['due_date']).split('T').first}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        pw.Text('Billed to', style: bold),
        pw.Text(_s(client['name'])),
        if (_s(client['email']).isNotEmpty) pw.Text(_s(client['email'])),
        if (_s(client['gstin']).isNotEmpty) pw.Text('GSTIN: ${_s(client['gstin'])}'),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: const ['Description', 'Qty', 'Unit price', 'GST %', 'Amount'],
          headerStyle: bold,
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(2),
          },
          data: [
            for (final it in items)
              [
                _s(it['description']),
                _n(it['quantity']).toStringAsFixed(0),
                _money(_n(it['unit_price'])),
                '${_n(it['gst_percent']).toStringAsFixed(0)}%',
                _money(_n(it['amount'])),
              ],
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Subtotal: ${_money(_n(inv['subtotal']))}'),
              pw.Text('GST: ${_money(_n(inv['gst_total']))}'),
              pw.SizedBox(height: 4),
              pw.Text('Total: ${_money(_n(inv['total']))}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        if (_s(settings['bank_name']).isNotEmpty || _s(settings['bank_account']).isNotEmpty) ...[
          pw.SizedBox(height: 24),
          pw.Text('Bank details', style: bold),
          if (_s(settings['bank_name']).isNotEmpty) pw.Text('Bank: ${_s(settings['bank_name'])}'),
          if (_s(settings['bank_account']).isNotEmpty) pw.Text('Account: ${_s(settings['bank_account'])}'),
          if (_s(settings['ifsc']).isNotEmpty) pw.Text('IFSC: ${_s(settings['ifsc'])}'),
        ],
        if (_s(inv['notes']).isNotEmpty) ...[
          pw.SizedBox(height: 16),
          pw.Text('Notes', style: bold),
          pw.Text(_s(inv['notes'])),
        ],
      ],
    ),
  );

  final dir = await getTemporaryDirectory();
  final number = _s(inv['invoice_number']).isEmpty ? 'invoice' : _s(inv['invoice_number']);
  final file = File('${dir.path}/$number.pdf');
  await file.writeAsBytes(await doc.save());

  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')], subject: 'Invoice $number'),
  );
}
