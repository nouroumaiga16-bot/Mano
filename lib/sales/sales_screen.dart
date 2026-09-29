import 'package:flutter/material.dart';

import '../data/database.dart';
import '../settings/shop_screen.dart';
import '../utils/format.dart';
import 'new_sale_screen.dart';
import 'payment.dart';
import 'sale_detail_screen.dart';
import '../widgets/data_error.dart';

/// Liste des ventes (factures), des plus récentes aux plus anciennes.
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  late final _sales = widget.database.watchSales();
  late final _today = widget.database.watchDaySales(DateTime.now());

  void _newSale() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewSaleScreen(database: widget.database),
      ),
    );
  }

  void _openSale(Sale sale) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SaleDetailScreen(database: widget.database, saleId: sale.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes ventes'),
        actions: [
          IconButton(
            tooltip: 'Ma boutique',
            icon: const Icon(Icons.storefront),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShopScreen(database: widget.database),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _newSale,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Nouvelle vente'),
      ),
      body: Column(
        children: [
          StreamBuilder<DaySales>(
            stream: _today,
            builder: (context, snapshot) {
              final today = snapshot.data ?? const DaySales(count: 0, total: 0);
              return _TodayCard(today: today);
            },
          ),
          Expanded(
            child: StreamBuilder<List<Sale>>(
              stream: _sales,
              builder: (context, snapshot) {
                if (snapshot.error case final error?) {
                  return DataError(error: error);
                }
                final sales = snapshot.data;
                if (sales == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (sales.isEmpty) return const _EmptySales();
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: sales.length,
                  itemBuilder: (context, index) {
                    final sale = sales[index];
                    final day = formatDay(sale.createdAt);
                    final showHeader =
                        index == 0 ||
                        formatDay(sales[index - 1].createdAt) != day;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(
                              day,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                          ),
                        _SaleTile(sale: sale, onTap: () => _openSale(sale)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.today});

  final DaySales today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ventes d\'aujourd\'hui',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
            Text(
              formatFcfa(today.total),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            Text(
              '${today.count} vente${today.count > 1 ? 's' : ''}',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled = sale.cancelled;
    final title = [
      'Facture ${formatInvoiceNumber(sale.number)}',
      ?sale.customerName,
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        cancelled
            ? 'Annulée'
            : [
                formatTime(sale.createdAt),
                salePaymentLabel(sale),
                if (sale.unpaid > 0) 'reste ${formatFcfa(sale.unpaid)}',
              ].join(' · '),
        style: cancelled ? TextStyle(color: Colors.red.shade800) : null,
      ),
      trailing: Text(
        formatFcfa(sale.total),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          decoration: cancelled ? TextDecoration.lineThrough : null,
          color: cancelled ? Theme.of(context).colorScheme.outline : null,
        ),
      ),
    );
  }
}

class _EmptySales extends StatelessWidget {
  const _EmptySales();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune vente pour le moment.\n'
              'Appuyez sur « Nouvelle vente » pour commencer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
