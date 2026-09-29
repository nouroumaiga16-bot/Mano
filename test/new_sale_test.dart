import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';
import 'package:mano/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('faire une vente depuis l\'onglet Ventes', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final productId = (await tester.runAsync(
      () => db.addProduct(
        name: 'Sacs Louis Vuitton',
        purchasePrice: 2500,
        salePrice: 7000,
        quantity: 1,
        lowStockThreshold: 5,
      ),
    ))!;

    await tester.pumpWidget(ManoApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ventes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucune vente'), findsOneWidget);

    await tester.tap(find.text('Nouvelle vente'));
    await tester.pumpAndSettle();

    // Le choix du produit s'ouvre tout seul.
    await tester.tap(find.text('Sacs Louis Vuitton'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Il n\'en reste que 1 en stock'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Remise sur le total (facultatif)'),
      '1000',
    );
    await tester.tap(find.text('Wave'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Nom du client'),
      'Awa',
    );
    await tester.pumpAndSettle();
    expect(find.text('13 000 FCFA'), findsOneWidget);

    await tester.tap(find.text('Valider la vente'));
    await tester.pumpAndSettle();

    expect(find.text('Facture N° 0001'), findsOneWidget);
    expect(find.textContaining('Client : Awa'), findsOneWidget);
    expect(find.text('Envoyer la facture (WhatsApp...)'), findsOneWidget);
    final product = await tester.runAsync(
      () => db.watchProduct(productId).first,
    );
    expect(product!.quantity, -1);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Facture N° 0001 · Awa'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
