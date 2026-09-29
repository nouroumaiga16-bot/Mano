import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database.dart';
import '../utils/format.dart';
import 'payment.dart';

/// Police Roboto : les polices de base du PDF ne connaissent pas tous les
/// caractères (apostrophe ’ de l'iPhone, espace fine des montants...).
pw.ThemeData? _theme;

Future<pw.ThemeData> _loadTheme() async {
  if (_theme case final theme?) return theme;
  Future<pw.Font> load(String name) async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-$name.ttf'));
  return _theme = pw.ThemeData.withFont(
    base: await load('Regular'),
    bold: await load('Bold'),
    italic: await load('Italic'),
  );
}

String invoiceFileName(Sale sale) =>
    'Facture-${sale.number.toString().padLeft(4, '0')}.pdf';

/// Fabrique la facture PDF (format A5, facile à lire sur un téléphone).
Future<Uint8List> buildInvoicePdf({
  required Sale sale,
  required List<SaleItem> items,
  required ShopInfo shop,
}) async {
  final theme = await _loadTheme();
  const green = PdfColor.fromInt(0xFF1B7F5A);
  final doc = pw.Document(
    theme: theme,
    title: 'Facture ${formatInvoiceNumber(sale.number)}',
    author: shop.name.isEmpty ? 'Mano' : shop.name,
  );

  pw.Widget totalRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 13 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (shop.logo case final logo?) ...[
                pw.SizedBox(
                  width: 64,
                  height: 64,
                  child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 12),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      shop.name.isEmpty ? 'Facture' : shop.name,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: green,
                      ),
                    ),
                    if (shop.address.isNotEmpty) pw.Text(shop.address),
                    if (shop.phone.isNotEmpty)
                      pw.Text('Tél. : ${formatPhone(shop.phone)}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'FACTURE ${formatInvoiceNumber(sale.number)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(formatDateTime(sale.createdAt)),
                ],
              ),
              if (sale.customerName != null || sale.customerPhone != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Client'),
                    if (sale.customerName != null)
                      pw.Text(
                        sale.customerName!,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    if (sale.customerPhone != null)
                      pw.Text(formatPhone(sale.customerPhone!)),
                  ],
                ),
            ],
          ),
          if (sale.cancelled)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                'FACTURE ANNULÉE',
                style: pw.TextStyle(
                  color: PdfColors.red,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Article', 'Qté', 'Prix', 'Total'],
            data: [
              for (final item in items)
                [
                  item.productName,
                  formatNumber(item.quantity),
                  formatNumber(item.unitPrice),
                  formatNumber(item.total),
                ],
            ],
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(color: green),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.8),
            },
          ),
          pw.SizedBox(height: 12),
          if (sale.discount > 0) ...[
            totalRow('Sous-total', formatFcfa(sale.subtotal)),
            totalRow('Remise', '- ${formatFcfa(sale.discount)}'),
          ],
          pw.Divider(color: PdfColors.grey400),
          totalRow('TOTAL', formatFcfa(sale.total), bold: true),
          totalRow('Paiement', paymentLabel(sale.paymentMethod)),
          pw.Spacer(),
          pw.Center(
            child: pw.Text(
              'Merci pour votre achat !',
              style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
            ),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}
