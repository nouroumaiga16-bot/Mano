import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';
import 'package:mano/utils/contact.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Product> addSac() async {
    final id = await db.addProduct(
      name: 'Sac',
      purchasePrice: 2500,
      salePrice: 7000,
      quantity: 10,
      lowStockThreshold: 2,
    );
    return (await db.watchProduct(id).first)!;
  }

  Future<Customer> addAicha() async {
    final id = await db.addCustomer(
      name: 'Aïcha',
      phone: '76363832',
      neighborhood: 'Larlé',
      note: 'paie en fin de mois',
    );
    return (await db.watchCustomer(id).first).customer;
  }

  Future<int> balance(Customer c) async =>
      (await db.watchCustomer(c.id).first).balance;

  test('vente à crédit, remboursements et historique', () async {
    final sac = await addSac();
    final aicha = await addAicha();
    expect(aicha.neighborhood, 'Larlé');
    expect(await balance(aicha), 0);

    final saleId = await db.createSale(
      lines: [SaleLineInput(product: sac, quantity: 1, unitPrice: 7000)],
      paymentMethod: PaymentMethod.cash,
      customer: aicha,
      amountPaid: 3000,
    );
    final sale = await db.watchSale(saleId).first;
    expect(sale.customerId, aicha.id);
    expect(sale.customerName, 'Aïcha');
    expect(sale.unpaid, 4000);
    expect(await balance(aicha), 4000);

    await db.addPayment(
      customerId: aicha.id,
      amount: 1500,
      method: PaymentMethod.orangeMoney,
      date: DateTime.now().add(const Duration(minutes: 1)),
    );
    expect(await balance(aicha), 2500);

    // Impossible de payer plus que la dette.
    expect(
      () => db.addPayment(
        customerId: aicha.id,
        amount: 3000,
        method: PaymentMethod.cash,
      ),
      throwsArgumentError,
    );

    final history = await db.watchCustomerHistory(aicha.id).first;
    expect(history.first, isA<PaymentEvent>());
    expect(history.last, isA<PurchaseEvent>());

    final list = await db.watchCustomers().first;
    expect(list.single.balance, 2500);
  });

  test('annuler une vente à crédit efface la dette', () async {
    final sac = await addSac();
    final aicha = await addAicha();
    final saleId = await db.createSale(
      lines: [SaleLineInput(product: sac, quantity: 1, unitPrice: 7000)],
      paymentMethod: PaymentMethod.cash,
      customer: aicha,
      amountPaid: 0,
    );
    expect(await balance(aicha), 7000);
    await db.cancelSale(saleId);
    expect(await balance(aicha), 0);
  });

  test('une vente à crédit sans client est refusée', () async {
    final sac = await addSac();
    expect(
      () => db.createSale(
        lines: [SaleLineInput(product: sac, quantity: 1, unitPrice: 7000)],
        paymentMethod: PaymentMethod.cash,
        amountPaid: 1000,
      ),
      throwsArgumentError,
    );
  });

  test('modifier et supprimer un client', () async {
    final aicha = await addAicha();
    await db.updateCustomer(aicha.id, name: 'Aïcha K.', phone: '', note: '');
    final updated = (await db.watchCustomer(aicha.id).first).customer;
    expect(updated.name, 'Aïcha K.');
    expect(updated.phone, isNull);
    expect(updated.neighborhood, isNull);
    await db.deleteCustomer(aicha.id);
    expect(await db.watchCustomers().first, isEmpty);
  });

  test(
    'mise à jour v3 -> v4 : les clients des anciennes ventes sont créés',
    () async {
      final dir = await Directory.systemTemp.createTemp('mano');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/mano.sqlite');

      // Base au format v4, ramenée au format v3 (sans clients ni paiements).
      final first = AppDatabase(NativeDatabase(file));
      final productId = await first.addProduct(
        name: 'Sac',
        purchasePrice: 2500,
        salePrice: 7000,
        quantity: 10,
        lowStockThreshold: 2,
      );
      final sac = (await first.watchProduct(productId).first)!;
      for (var i = 0; i < 2; i++) {
        await first.createSale(
          lines: [SaleLineInput(product: sac, quantity: 1, unitPrice: 7000)],
          paymentMethod: PaymentMethod.cash,
        );
      }
      await first.customStatement(
        "UPDATE sales SET customer_name = 'Aïcha', customer_phone = '76363832'",
      );
      await first.customStatement('DROP TABLE payments');
      await first.customStatement('DROP TABLE customers');
      await first.customStatement('ALTER TABLE sales DROP COLUMN customer_id');
      await first.customStatement('PRAGMA user_version = 3');
      await first.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      addTearDown(upgraded.close);
      final customers = await upgraded.watchCustomers().first;
      expect(customers.single.customer.name, 'Aïcha');
      expect(customers.single.customer.phone, '76363832');
      expect(customers.single.balance, 0);
      final history = await upgraded
          .watchCustomerHistory(customers.single.customer.id)
          .first;
      expect(history.length, 2);
    },
  );

  test('rappel WhatsApp', () {
    expect(internationalPhone('76 36 38 32'), '22676363832');
    expect(internationalPhone('+226 76363832'), '22676363832');
    expect(internationalPhone('123'), isNull);
    final message = reminderMessage(
      customerName: 'Aïcha',
      balance: 4000,
      shopName: 'Maiga Market',
    );
    expect(
      message,
      'Bonjour Aïcha, petit rappel : il reste 4 000 FCFA à régler chez '
      'Maiga Market. Merci beaucoup !',
    );
    final uri = whatsappUri('76363832', message)!;
    expect(uri.host, 'wa.me');
    expect(uri.path, '/22676363832');
    expect(uri.queryParameters['text'], message);
  });
}
