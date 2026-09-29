import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<String> addSoap({int quantity = 10}) => db.addProduct(
    name: 'Savon',
    purchasePrice: 200,
    salePrice: 250,
    quantity: quantity,
    lowStockThreshold: 5,
  );

  test('ajouter un produit enregistre le stock de départ', () async {
    final id = await addSoap();
    final product = await db.watchProduct(id).first;
    expect(product!.quantity, 10);
    expect(product.unitProfit, 50);

    final movements = await db.watchMovements(id).first;
    expect(movements.single.reason, MovementReason.initial);
    expect(movements.single.change, 10);
  });

  test('ajouter du stock et corriger la quantité', () async {
    final id = await addSoap();
    await db.addStock(id, 5, note: 'Livraison');
    expect((await db.watchProduct(id).first)!.quantity, 15);

    await db.setQuantity(id, 12, note: '3 cassés');
    expect((await db.watchProduct(id).first)!.quantity, 12);

    final movements = await db.watchMovements(id).first;
    expect(movements.map((m) => m.change), [-3, 5, 10]);
    expect(movements.first.note, '3 cassés');
  });

  test('stock bas, recherche et résumé', () async {
    await addSoap(quantity: 3);
    await db.addProduct(
      name: 'Riz 25 kg',
      purchasePrice: 15000,
      salePrice: 17500,
      quantity: 20,
      lowStockThreshold: 5,
    );

    final low = await db.watchProducts(lowOnly: true).first;
    expect(low.map((p) => p.name), ['Savon']);
    expect(low.single.isLowStock, isTrue);

    final found = await db.watchProducts(search: 'RIZ').first;
    expect(found.map((p) => p.name), ['Riz 25 kg']);

    final summary = await db.watchSummary().first;
    expect(summary.productCount, 2);
    expect(summary.lowStockCount, 1);
    expect(summary.stockValue, 3 * 200 + 20 * 15000);
  });

  test('un produit supprimé disparaît de la liste et du résumé', () async {
    final id = await addSoap();
    await db.deleteProduct(id);
    expect(await db.watchProducts().first, isEmpty);
    expect((await db.watchSummary().first).productCount, 0);
  });

  test(
    'couleur, taille, catégorie : recherche, filtre et nom affiché',
    () async {
      await db.addProduct(
        name: 'Sac Louis Vuitton',
        purchasePrice: 2500,
        salePrice: 7000,
        quantity: 5,
        lowStockThreshold: 2,
        color: ' Noir ',
        category: 'Sacs',
      );
      await db.addProduct(
        name: 'Basket',
        purchasePrice: 5000,
        salePrice: 9000,
        quantity: 5,
        lowStockThreshold: 2,
        color: 'Blanc',
        size: '42',
        category: 'Chaussures',
      );

      final all = await db.watchProducts().first;
      expect(all.map((p) => p.displayName), [
        'Basket · Blanc · Taille 42',
        'Sac Louis Vuitton · Noir',
      ]);
      expect(
        (await db.watchProducts(search: 'noir').first).single.name,
        'Sac Louis Vuitton',
      );
      expect(
        (await db.watchProducts(category: 'Chaussures').first).single.name,
        'Basket',
      );
      expect(await db.watchDistinct(db.products.category).first, [
        'Chaussures',
        'Sacs',
      ]);
    },
  );

  test('photo du produit : ajout, remplacement, suppression', () async {
    final id = await addSoap();
    expect(await db.watchPhoto(id).first, isNull);
    await db.setPhoto(id, Uint8List.fromList([1, 2, 3]));
    await db.setPhoto(id, Uint8List.fromList([4, 5]));
    expect(await db.watchPhoto(id).first, [4, 5]);
    await db.setPhoto(id, null);
    expect(await db.watchPhoto(id).first, isNull);
  });
}
