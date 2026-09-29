import 'package:flutter/material.dart';

import '../data/database.dart';
import '../sales/payment.dart';
import '../sales/sale_detail_screen.dart';
import '../sales/sales_screen.dart';
import '../stock/product_form_screen.dart';
import '../theme.dart';
import '../utils/format.dart';

/// Accueil : ventes du jour, raccourcis et dernières ventes.
class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.database,
    required this.onNewSale,
    required this.onOpenTab,
  });

  final AppDatabase database;
  final VoidCallback onNewSale;

  /// Ouvre un onglet de la barre du bas (Stock, Clients, Bilan).
  final void Function(HomeDestination) onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

enum HomeDestination { stock, customers, dashboard }

class _HomeTabState extends State<HomeTab> {
  AppDatabase get _db => widget.database;
  late final _shop = _db.watchShopInfo();
  late final _today = _db.watchDaySales(DateTime.now());
  late final _sales = _db.watchSales();
  late final _stock = _db.watchSummary();
  bool _hidden = false;

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Header(
          shop: _shop,
          today: _today,
          hidden: _hidden,
          onToggleHidden: () => setState(() => _hidden = !_hidden),
          onNewSale: widget.onNewSale,
          onAddProduct: () => _push(ProductFormScreen(database: _db)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: StreamBuilder<StockSummary>(
                stream: _stock,
                builder: (context, snapshot) {
                  final low = snapshot.data?.lowStockCount ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Shortcut(
                        icon: Icons.inventory_2_outlined,
                        label: low > 0 ? 'Stock bas' : 'Stock',
                        color: low > 0
                            ? Colors.orange.shade800
                            : Colors.teal.shade700,
                        onTap: () => widget.onOpenTab(HomeDestination.stock),
                      ),
                      _Shortcut(
                        icon: Icons.payments_outlined,
                        label: 'Encaisser',
                        color: Colors.green.shade700,
                        onTap: () =>
                            widget.onOpenTab(HomeDestination.customers),
                      ),
                      _Shortcut(
                        icon: Icons.receipt_long_outlined,
                        label: 'Factures',
                        color: Colors.indigo.shade400,
                        onTap: () => _push(SalesScreen(database: _db)),
                      ),
                      _Shortcut(
                        icon: Icons.bar_chart,
                        label: 'Bilan',
                        color: Colors.amber.shade800,
                        onTap: () =>
                            widget.onOpenTab(HomeDestination.dashboard),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: StreamBuilder<List<Sale>>(
                stream: _sales,
                builder: (context, snapshot) {
                  final sales = (snapshot.data ?? const <Sale>[])
                      .take(5)
                      .toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dernières ventes',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _push(SalesScreen(database: _db)),
                            child: const Text('Tout voir'),
                          ),
                        ],
                      ),
                      if (sales.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('Aucune vente pour le moment.'),
                        ),
                      for (final sale in sales)
                        _RecentSale(
                          sale: sale,
                          hidden: _hidden,
                          onTap: () => _push(
                            SaleDetailScreen(database: _db, saleId: sale.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.shop,
    required this.today,
    required this.hidden,
    required this.onToggleHidden,
    required this.onNewSale,
    required this.onAddProduct,
  });

  final Stream<ShopInfo> shop;
  final Stream<DaySales> today;
  final bool hidden;
  final VoidCallback onToggleHidden;
  final VoidCallback onNewSale;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, top + 16, 20, 28),
      decoration: const BoxDecoration(
        color: ManoColors.forest,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          StreamBuilder<ShopInfo>(
            stream: shop,
            builder: (context, snapshot) {
              final info = snapshot.data ?? const ShopInfo();
              return Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: info.logo == null
                        ? null
                        : MemoryImage(info.logo!),
                    child: info.logo == null
                        ? const Icon(Icons.storefront, color: ManoColors.forest)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bonjour,\n${info.name.isEmpty ? 'bienvenue' : info.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'Ventes du jour',
            style: TextStyle(color: ManoColors.lime, fontSize: 16),
          ),
          const SizedBox(height: 4),
          StreamBuilder<DaySales>(
            stream: today,
            builder: (context, snapshot) {
              final day = snapshot.data ?? const DaySales(count: 0, total: 0);
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          child: Text(
                            hidden ? '••••• FCFA' : formatFcfa(day.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: hidden ? 'Afficher' : 'Cacher le montant',
                        onPressed: onToggleHidden,
                        icon: Icon(
                          hidden ? Icons.visibility_off : Icons.visibility,
                          color: ManoColors.lime,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${day.count} vente${day.count > 1 ? 's' : ''} aujourd\'hui',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _LimeButton(label: 'Nouvelle vente', onTap: onNewSale),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LimeButton(
                  label: 'Ajouter un produit',
                  onTap: onAddProduct,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimeButton extends StatelessWidget {
  const _LimeButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: ManoColors.lime,
        foregroundColor: ManoColors.forest,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSale extends StatelessWidget {
  const _RecentSale({
    required this.sale,
    required this.hidden,
    required this.onTap,
  });

  final Sale sale;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final credit = sale.unpaid > 0;
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 8),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: credit ? Colors.red.shade50 : Colors.green.shade50,
        child: Icon(
          credit ? Icons.schedule : Icons.check,
          color: credit ? Colors.red.shade800 : Colors.green.shade800,
        ),
      ),
      title: Text(
        sale.customerName ?? 'Facture ${formatInvoiceNumber(sale.number)}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        sale.cancelled
            ? 'Annulée'
            : credit
            ? 'Crédit · reste ${formatFcfa(sale.unpaid)}'
            : salePaymentLabel(sale),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            hidden ? '•••' : formatFcfa(sale.total),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: sale.cancelled ? TextDecoration.lineThrough : null,
            ),
          ),
          Text(
            formatDay(sale.createdAt) == 'Aujourd\'hui'
                ? formatTime(sale.createdAt)
                : formatDate(sale.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
