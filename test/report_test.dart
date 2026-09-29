import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mano/data/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('périodes : jour, mois, année', () {
    final range = ReportRange(ReportPeriod.month, DateTime(2026, 2, 14, 10));
    expect(range.start, DateTime(2026, 2));
    expect(range.end, DateTime(2026, 3));
    expect(range.buckets.length, 28);
    expect(range.previous.start, DateTime(2026, 1));
    final year = ReportRange(ReportPeriod.year, DateTime(2026, 12, 31));
    expect(year.next.start, DateTime(2027));
    expect(year.buckets.length, 12);
    final day = ReportRange(ReportPeriod.day, DateTime(2026, 3, 1, 23));
    expect(day.previous.start, DateTime(2026, 2, 28));
  });

  test(
    'chiffre d\'affaires, bénéfice, argent reçu, meilleurs produits',
    () async {
      Future<Product> add(String name, int buy, int sell) async {
        final id = await db.addProduct(
          name: name,
          purchasePrice: buy,
          salePrice: sell,
          quantity: 50,
          lowStockThreshold: 2,
        );
        return (await db.watchProduct(id).first)!;
      }

      final sac = await add('Sac', 2500, 7000);
      final pagne = await add('Pagne', 3000, 5000);
      final customerId = await db.addCustomer(name: 'Aïcha');
      final aicha = (await db.watchCustomer(customerId).first).customer;

      // Vente 1 : 2 sacs, remise 1 000 -> CA 13 000, bénéfice 9 000 - 1 000.
      await db.createSale(
        lines: [SaleLineInput(product: sac, quantity: 2, unitPrice: 7000)],
        discount: 1000,
        paymentMethod: PaymentMethod.cash,
      );
      // Vente 2 à crédit : 1 pagne, 2 000 payés -> CA 5 000, bénéfice 2 000.
      await db.createSale(
        lines: [SaleLineInput(product: pagne, quantity: 1, unitPrice: 5000)],
        paymentMethod: PaymentMethod.cash,
        customer: aicha,
        amountPaid: 2000,
      );
      // Vente 3 annulée : ne compte pas.
      final cancelled = await db.createSale(
        lines: [SaleLineInput(product: pagne, quantity: 5, unitPrice: 5000)],
        paymentMethod: PaymentMethod.wave,
      );
      await db.cancelSale(cancelled);
      // Remboursement de 1 000.
      await db.addPayment(
        customerId: aicha.id,
        amount: 1000,
        method: PaymentMethod.orangeMoney,
      );

      final now = DateTime.now();
      for (final period in ReportPeriod.values) {
        final report = await db.watchReport(ReportRange(period, now)).first;
        expect(report.revenue, 18000, reason: '$period');
        expect(report.profit, 10000, reason: '$period');
        expect(report.salesCount, 2, reason: '$period');
        expect(report.cashIn, 13000 + 2000 + 1000, reason: '$period');
        expect(report.topProducts.map((p) => (p.name, p.quantity)), [
          ('Sac', 2),
          ('Pagne', 1),
        ]);
      }

      final month = await db
          .watchReport(ReportRange(ReportPeriod.month, now))
          .first;
      expect(
        month.revenueByBucket[DateTime(now.year, now.month, now.day)],
        18000,
      );
      final year = await db
          .watchReport(ReportRange(ReportPeriod.year, now))
          .first;
      expect(year.revenueByBucket[DateTime(now.year, now.month)], 18000);

      final lastYear = await db
          .watchReport(ReportRange(ReportPeriod.year, now).previous)
          .first;
      expect(lastYear.revenue, 0);
      expect(lastYear.topProducts, isEmpty);
    },
  );
}
