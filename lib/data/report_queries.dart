part of 'database.dart';

enum ReportPeriod { day, month, year }

const _monthNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

String monthName(int month) => _monthNames[month - 1];

/// Une période de bilan : un jour, un mois ou une année.
class ReportRange {
  ReportRange(this.period, DateTime anchor)
    : start = switch (period) {
        ReportPeriod.day => DateTime(anchor.year, anchor.month, anchor.day),
        ReportPeriod.month => DateTime(anchor.year, anchor.month),
        ReportPeriod.year => DateTime(anchor.year),
      };

  final ReportPeriod period;
  final DateTime start;

  DateTime get end => _shift(1);

  ReportRange get previous => ReportRange(period, _shift(-1));
  ReportRange get next => ReportRange(period, _shift(1));

  /// La période contient-elle aujourd'hui ? (Pas de « suivant » au-delà.)
  bool get isCurrent {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  DateTime _shift(int steps) => switch (period) {
    ReportPeriod.day => DateTime(start.year, start.month, start.day + steps),
    ReportPeriod.month => DateTime(start.year, start.month + steps),
    ReportPeriod.year => DateTime(start.year + steps),
  };

  /// Périodes du graphique : les jours du mois, ou les mois de l'année.
  List<DateTime> get buckets => switch (period) {
    ReportPeriod.day => const [],
    ReportPeriod.month => [
      for (
        var d = start;
        d.isBefore(end);
        d = DateTime(d.year, d.month, d.day + 1)
      )
        d,
    ],
    ReportPeriod.year => [
      for (var m = 1; m <= 12; m++) DateTime(start.year, m),
    ],
  };

  DateTime bucketOf(DateTime date) => switch (period) {
    ReportPeriod.day => start,
    ReportPeriod.month => DateTime(date.year, date.month, date.day),
    ReportPeriod.year => DateTime(date.year, date.month),
  };
}

class TopProduct {
  const TopProduct(this.name, this.quantity, this.revenue);

  final String name;
  final int quantity;
  final int revenue;
}

class Report {
  const Report({
    required this.revenue,
    required this.profit,
    required this.salesCount,
    required this.cashIn,
    required this.revenueByBucket,
    required this.topProducts,
  });

  /// Chiffre d'affaires : total des ventes non annulées (crédits compris).
  final int revenue;

  /// Bénéfice : (prix de vente − prix d'achat) × quantité, moins les remises.
  final int profit;
  final int salesCount;

  /// Argent reçu : payé au moment des ventes + remboursements de crédits.
  final int cashIn;

  /// Chiffre d'affaires par jour (bilan du mois) ou par mois (bilan de l'année).
  final Map<DateTime, int> revenueByBucket;
  final List<TopProduct> topProducts;
}

extension ReportQueries on AppDatabase {
  Stream<Report> watchReport(ReportRange range) {
    // Requête vide qui se relance dès qu'une vente ou un paiement change.
    return customSelect(
      'SELECT 1',
      readsFrom: {sales, saleItems, payments},
    ).watch().asyncMap((_) => _report(range));
  }

  Future<Report> _report(ReportRange range) async {
    final period = [
      Variable.withDateTime(range.start),
      Variable.withDateTime(range.end),
    ];
    final saleRows = await customSelect(
      'SELECT s.created_at, s.total, s.amount_paid, s.discount, '
      '  (SELECT COALESCE(SUM((i.unit_price - i.purchase_price) * i.quantity), 0)'
      '   FROM sale_items i WHERE i.sale_id = s.id) AS margin '
      'FROM sales s '
      'WHERE s.cancelled = 0 AND s.created_at >= ? AND s.created_at < ?',
      variables: period,
      readsFrom: {sales, saleItems},
    ).get();

    var revenue = 0, profit = 0, cashIn = 0;
    final byBucket = {for (final bucket in range.buckets) bucket: 0};
    for (final row in saleRows) {
      final total = row.read<int>('total');
      revenue += total;
      profit += row.read<int>('margin') - row.read<int>('discount');
      cashIn += row.read<int>('amount_paid');
      final bucket = range.bucketOf(row.read<DateTime>('created_at'));
      if (byBucket.containsKey(bucket)) {
        byBucket[bucket] = byBucket[bucket]! + total;
      }
    }

    final repaid = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS amount FROM payments '
      'WHERE created_at >= ? AND created_at < ?',
      variables: period,
      readsFrom: {payments},
    ).getSingle();
    cashIn += repaid.read<int>('amount');

    final topRows = await customSelect(
      'SELECT i.product_name, SUM(i.quantity) AS quantity, '
      '  SUM(i.quantity * i.unit_price) AS revenue '
      'FROM sale_items i JOIN sales s ON s.id = i.sale_id '
      'WHERE s.cancelled = 0 AND s.created_at >= ? AND s.created_at < ? '
      'GROUP BY i.product_name ORDER BY quantity DESC, revenue DESC LIMIT 5',
      variables: period,
      readsFrom: {sales, saleItems},
    ).get();

    return Report(
      revenue: revenue,
      profit: profit,
      salesCount: saleRows.length,
      cashIn: cashIn,
      revenueByBucket: byBucket,
      topProducts: [
        for (final row in topRows)
          TopProduct(
            row.read<String>('product_name'),
            row.read<int>('quantity'),
            row.read<int>('revenue'),
          ),
      ],
    );
  }
}
