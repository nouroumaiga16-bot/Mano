import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';
import 'package:mano/sales/invoice_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('la facture PDF est générée', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addProduct(
      name: 'Sac à main « Awa »',
      purchasePrice: 2500,
      salePrice: 7000,
      quantity: 5,
      lowStockThreshold: 2,
    );
    final product = (await db.watchProduct(id).first)!;
    final saleId = await db.createSale(
      lines: [SaleLineInput(product: product, quantity: 2, unitPrice: 6500)],
      discount: 1000,
      paymentMethod: PaymentMethod.wave,
      customerName: 'Awa Ouédraogo — l’aînée',
      customerPhone: '70 12 34 56',
    );
    final sale = await db.watchSale(saleId).first;
    final items = await db.watchSaleItems(saleId).first;

    final bytes = await buildInvoicePdf(
      sale: sale,
      items: items,
      shop: const ShopInfo(name: 'Boutique Awa', phone: '70 00 00 00'),
    );
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    expect(invoiceFileName(sale), 'Facture-0001.pdf');
    const out = String.fromEnvironment('PDF_OUT');
    if (out.isNotEmpty) File(out).writeAsBytesSync(bytes);
  });
}
