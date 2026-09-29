import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Product> addProduct(
    String name,
    int purchase,
    int sale,
    int qty,
  ) async {
    final id = await db.addProduct(
      name: name,
      purchasePrice: purchase,
      salePrice: sale,
      quantity: qty,
      lowStockThreshold: 2,
    );
    return (await db.watchProduct(id).first)!;
  }

  test('une vente baisse le stock et numérote les factures', () async {
    final sac = await addProduct('Sac', 2500, 7000, 25);
    final pagne = await addProduct('Pagne', 3000, 5000, 10);

    final id = await db.createSale(
      lines: [
        SaleLineInput(product: sac, quantity: 2, unitPrice: 6500),
        SaleLineInput(product: pagne, quantity: 1, unitPrice: 5000),
      ],
      discount: 1000,
      paymentMethod: PaymentMethod.orangeMoney,
      customerName: '  Awa ',
      customerPhone: '',
    );

    final sale = await db.watchSale(id).first;
    expect(sale.number, 1);
    expect(sale.subtotal, 18000);
    expect(sale.total, 17000);
    expect(sale.amountPaid, 17000);
    expect(sale.customerName, 'Awa');
    expect(sale.customerPhone, isNull);
    expect(sale.paymentMethod, PaymentMethod.orangeMoney);

    final items = await db.watchSaleItems(id).first;
    expect(items.map((i) => (i.productName, i.quantity, i.total)), [
      ('Sac', 2, 13000),
      ('Pagne', 1, 5000),
    ]);
    expect((await db.watchProduct(sac.id).first)!.quantity, 23);
    expect((await db.watchProduct(pagne.id).first)!.quantity, 9);

    final movement = (await db.watchMovements(sac.id).first).first;
    expect(movement.reason, MovementReason.sale);
    expect(movement.change, -2);
    expect(movement.note, 'Facture N° 0001');

    final second = await db.createSale(
      lines: [SaleLineInput(product: sac, quantity: 1, unitPrice: 7000)],
      paymentMethod: PaymentMethod.cash,
    );
    expect((await db.watchSale(second).first).number, 2);

    final today = await db.watchDaySales(DateTime.now()).first;
    expect(today.count, 2);
    expect(today.total, 24000);
  });

  test(
    'on peut vendre plus que le stock (la quantité devient négative)',
    () async {
      final sac = await addProduct('Sac', 2500, 7000, 1);
      await db.createSale(
        lines: [SaleLineInput(product: sac, quantity: 3, unitPrice: 7000)],
        paymentMethod: PaymentMethod.wave,
      );
      expect((await db.watchProduct(sac.id).first)!.quantity, -2);
    },
  );

  test(
    'annuler une vente remet le stock et la retire du total du jour',
    () async {
      final sac = await addProduct('Sac', 2500, 7000, 5);
      final id = await db.createSale(
        lines: [SaleLineInput(product: sac, quantity: 2, unitPrice: 7000)],
        paymentMethod: PaymentMethod.cash,
      );
      await db.cancelSale(id);
      await db.cancelSale(id); // Deux fois : sans effet la deuxième fois.

      expect((await db.watchSale(id).first).cancelled, isTrue);
      expect((await db.watchProduct(sac.id).first)!.quantity, 5);
      expect((await db.watchDaySales(DateTime.now()).first).total, 0);
      final movements = await db.watchMovements(sac.id).first;
      expect(movements.first.reason, MovementReason.saleCancelled);
    },
  );

  test('remise invalide refusée', () async {
    final sac = await addProduct('Sac', 2500, 7000, 5);
    expect(
      () => db.createSale(
        lines: [SaleLineInput(product: sac, quantity: 1, unitPrice: 7000)],
        discount: 8000,
        paymentMethod: PaymentMethod.cash,
      ),
      throwsArgumentError,
    );
  });

  test('informations de la boutique', () async {
    expect((await db.watchShopInfo().first).isEmpty, isTrue);
    await db.saveShopInfo(
      const ShopInfo(name: 'Boutique Awa', phone: '70 00 00 00'),
    );
    final info = await db.watchShopInfo().first;
    expect(info.name, 'Boutique Awa');
    expect(info.phone, '70 00 00 00');
    expect(info.address, '');
  });

  test('mise à jour depuis la version 1 sans perte de produits', () async {
    final old = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE "products" ("id" TEXT NOT NULL, "name" TEXT NOT NULL, "purchase_price" INTEGER NOT NULL, "sale_price" INTEGER NOT NULL, "quantity" INTEGER NOT NULL DEFAULT 0, "low_stock_threshold" INTEGER NOT NULL DEFAULT 5, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("deleted" IN (0, 1)), PRIMARY KEY ("id"));
CREATE TABLE "stock_movements" ("id" TEXT NOT NULL, "product_id" TEXT NOT NULL REFERENCES products (id), "change" INTEGER NOT NULL, "reason" TEXT NOT NULL, "note" TEXT NULL, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("id"));
INSERT INTO products (id, name, purchase_price, sale_price, quantity) VALUES ('p1', 'Sacs Louis Vuitton', 2500, 7000, 25);
INSERT INTO stock_movements (id, product_id, change, reason) VALUES ('m1', 'p1', 25, 'initial');
PRAGMA user_version = 1;
''');
        },
      ),
    );
    addTearDown(old.close);

    final products = await old.watchProducts().first;
    expect(products.single.name, 'Sacs Louis Vuitton');
    await old.createSale(
      lines: [
        SaleLineInput(product: products.single, quantity: 1, unitPrice: 7000),
      ],
      paymentMethod: PaymentMethod.cash,
    );
    expect((await old.watchProduct('p1').first)!.quantity, 24);
    expect((await old.watchMovements('p1').first).length, 2);
    // Colonnes ajoutées en version 3 : vides pour les anciens produits.
    final migrated = (await old.watchProduct('p1').first)!;
    expect(migrated.color, isNull);
    expect(migrated.displayName, 'Sacs Louis Vuitton');
  });
}
