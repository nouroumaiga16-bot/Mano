import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';

/// Base réelle (données de test) enregistrée à moitié sur le web : tables
/// clients et paiements déjà créées, mais version restée à 3.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('une mise à jour enregistrée à moitié est réparée', () async {
    final dir = await Directory.systemTemp.createTemp('mano');
    addTearDown(() => dir.delete(recursive: true));
    final file = await File(
      'test/fixtures/v3_half_migrated.sqlite',
    ).copy('${dir.path}/mano.sqlite');

    for (var run = 0; run < 2; run++) {
      final db = AppDatabase(NativeDatabase(file));
      await db.ensureOpen();
      final products = await db.watchProducts().first;
      expect(products.single.displayName, 'Sacs Louis Vuitton · Noir');
      expect((await db.watchPhoto(products.single.id).first), isNotNull);
      final shop = await db.watchShopInfo().first;
      expect(shop.name, 'Maiga Market');
      expect(shop.logo, isNotNull);
      final sales = await db.watchSales().first;
      expect(sales.length, 3);
      // Une seule Aïcha, reliée à ses deux ventes, même après deux ouvertures.
      final customers = await db.watchCustomers().first;
      expect(customers.map((c) => c.customer.name), ['Aïcha']);
      expect(
        sales.where((s) => s.customerId == customers.single.customer.id).length,
        2,
      );
      await db.close();
    }
  });
}
