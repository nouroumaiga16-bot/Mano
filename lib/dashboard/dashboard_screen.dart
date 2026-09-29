import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';
import 'revenue_chart.dart';

/// Bilan : chiffre d'affaires, bénéfice, ventes et meilleurs produits,
/// pour un jour, un mois ou une année.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ReportRange _range = ReportRange(ReportPeriod.day, DateTime.now());
  late Stream<Report> _report = widget.database.watchReport(_range);

  void _setRange(ReportRange range) => setState(() {
    _range = range;
    _report = widget.database.watchReport(range);
  });

  String get _title => switch (_range.period) {
    ReportPeriod.day => formatDay(_range.start),
    ReportPeriod.month =>
      '${monthName(_range.start.month)} ${_range.start.year}',
    ReportPeriod.year => '${_range.start.year}',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bilan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: const [
              ButtonSegment(value: ReportPeriod.day, label: Text('Jour')),
              ButtonSegment(value: ReportPeriod.month, label: Text('Mois')),
              ButtonSegment(value: ReportPeriod.year, label: Text('Année')),
            ],
            selected: {_range.period},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                _setRange(ReportRange(selection.first, DateTime.now())),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: 'Période précédente',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _setRange(_range.previous),
              ),
              Expanded(
                child: Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Période suivante',
                icon: const Icon(Icons.chevron_right),
                onPressed: _range.isCurrent
                    ? null
                    : () => _setRange(_range.next),
              ),
            ],
          ),
          StreamBuilder<Report>(
            stream: _report,
            builder: (context, snapshot) {
              final report = snapshot.data;
              if (report == null) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _ReportView(range: _range, report: report);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.range, required this.report});

  final ReportRange range;
  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Le chiffre principal de l'écran.
        Card(
          color: colors.primaryContainer,
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chiffre d\'affaires',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                Text(
                  formatFcfa(report.revenue),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'Bénéfice',
                value: formatFcfa(report.profit),
                negative: report.profit < 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'Ventes',
                value: formatNumber(report.salesCount),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StatTile(
          label: 'Argent reçu (crédits remboursés compris)',
          value: formatFcfa(report.cashIn),
        ),
        if (range.period != ReportPeriod.day) ...[
          const SizedBox(height: 24),
          Text(
            range.period == ReportPeriod.month
                ? 'Chiffre d\'affaires par jour'
                : 'Chiffre d\'affaires par mois',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RevenueChart(
            values: report.revenueByBucket,
            byMonth: range.period == ReportPeriod.year,
          ),
        ],
        const SizedBox(height: 24),
        Text('Produits les plus vendus', style: theme.textTheme.titleMedium),
        if (report.topProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Aucune vente sur cette période.'),
          )
        else
          for (final (index, product) in report.topProducts.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 16, child: Text('${index + 1}')),
              title: Text(product.name),
              subtitle: Text(formatFcfa(product.revenue)),
              trailing: Text(
                '${formatNumber(product.quantity)} vendu${product.quantity > 1 ? 's' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        if (range.period == ReportPeriod.year &&
            report.revenueByBucket.values.any((v) => v > 0)) ...[
          const SizedBox(height: 16),
          Text('Détail par mois', style: theme.textTheme.titleMedium),
          for (final entry in report.revenueByBucket.entries)
            if (entry.value > 0)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(monthName(entry.key.month)),
                trailing: Text(formatFcfa(entry.value)),
              ),
        ],
        const SizedBox(height: 16),
        Text(
          'Le bénéfice compte les ventes à crédit, même si elles ne sont pas '
          'encore payées. L\'argent reçu, lui, ne compte que ce qui est '
          'vraiment rentré.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.negative = false,
  });

  final String label;
  final String value;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: negative ? Colors.red.shade800 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
