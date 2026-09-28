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

    expect(find.textContaining('Aucun produit'), findsOneWidget);

    await tester.tap(find.text('Ajouter un produit'));
    await tester.pumpAndSettle();

    Future<void> fill(int index, String text) async {
      final field = find.byType(TextFormField).at(index);
      await tester.ensureVisible(field);
      await tester.enterText(field, text);
    }

    await fill(0, 'Savon');
    await fill(1, '200');
    await fill(2, '250');
    await fill(3, '3');
    await tester.pump();
    expect(find.textContaining('Bénéfice'), findsOneWidget);

    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(find.text('Savon'), findsOneWidget);
    expect(find.text('Stock bas'), findsWidgets);
    expect(find.text('1 produit est presque épuisé'), findsOneWidget);

    // Laisse drift fermer ses flux avant la fin du test.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
