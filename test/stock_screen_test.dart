import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';
import 'package:mano/main.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('créer un produit depuis l\'écran Stock', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(ManoApp(database: db));
    await tester.pumpAndSettle();

    // L'app s'ouvre sur l'Accueil ; on va dans l'onglet Stock.
    await tester.tap(find.text('Stock').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Aucun produit'), findsOneWidget);

    await tester.tap(find.text('Ajouter un produit'));
    await tester.pumpAndSettle();

    Future<void> fill(String label, String text) async {
      final field = find.widgetWithText(TextFormField, label);
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
    }

    await fill('Nom du produit', 'Savon');
    await fill('Couleur (facultatif)', 'Blanc');
    await fill('Prix d\'achat (par unité)', '200');
    await fill('Prix de vente (par unité)', '250');
    await fill('Quantité en stock', '3');
    await tester.pump();
    expect(find.textContaining('Bénéfice'), findsOneWidget);

    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Savon · Blanc'), findsOneWidget);
    expect(find.text('Stock bas'), findsWidgets);
    expect(find.text('1 produit est presque épuisé'), findsOneWidget);

    // Laisse drift fermer ses flux avant la fin du test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
