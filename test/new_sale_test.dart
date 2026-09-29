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
    // Accueil : aucune vente, puis le bouton « Nouvelle vente ».
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
    await tester.pumpAndSettle();

    // Client : création depuis la vente.
    await tester.ensureVisible(find.text('Choisir un client'));
    await tester.tap(find.text('Choisir un client'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nouveau client'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom du client'),
      'Awa',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone (facultatif)'),
      '76363832',
    );
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Awa'), findsOneWidget);
    expect(find.text('76 36 38 32'), findsOneWidget);

    // Vente à crédit : 5 000 payés sur 13 000.
    await tester.ensureVisible(find.text('Vente à crédit'));
    await tester.tap(find.text('Vente à crédit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Montant payé maintenant'),
      '5000',
    );
    await tester.pumpAndSettle();
    expect(find.text('13\u202F000\u202FFCFA'), findsOneWidget);
    expect(find.text('Reste à payer : 8\u202F000\u202FFCFA'), findsOneWidget);

    await tester.tap(find.text('Valider la vente'));
    await tester.pumpAndSettle();

    expect(find.text('Facture N° 0001'), findsOneWidget);
    expect(find.textContaining('Client : Awa · 76 36 38 32'), findsOneWidget);
    expect(find.text('Reste à payer'), findsOneWidget);
    expect(find.text('Envoyer la facture (WhatsApp...)'), findsOneWidget);
    final product = await tester.runAsync(
      () => db.watchProduct(productId).first,
    );
    expect(product!.quantity, -1);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    // Retour à l'Accueil : la vente est dans « Dernières ventes ».
    expect(find.text('Awa'), findsOneWidget);
    expect(find.textContaining('Crédit · reste 8'), findsOneWidget);

    // Onglet Clients : Awa doit 8 000, on enregistre un paiement de 3 000.
    await tester.tap(find.text('Clients'));
    await tester.pumpAndSettle();
    expect(find.text('8\u202F000\u202FFCFA'), findsWidgets);
    await tester.tap(find.text('Awa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer un paiement'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Montant reçu'),
      '3000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('5\u202F000\u202FFCFA'), findsOneWidget);
    expect(find.text('Rappeler par WhatsApp'), findsOneWidget);
    expect(find.text('+3\u202F000\u202FFCFA'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
