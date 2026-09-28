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
}
