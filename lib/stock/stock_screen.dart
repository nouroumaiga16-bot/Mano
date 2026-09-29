import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';
import '../widgets/product_thumbnail.dart';
import 'quantity_badge.dart';
import '../widgets/data_error.dart';

/// Écran principal du module Stock : la liste des produits.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  String _search = '';
  bool _lowOnly = false;
  String? _category;
  late Stream<List<Product>> _products;
  late final Stream<List<String>> _categories = widget.database.watchDistinct(
    widget.database.products.category,
  );
  late final Stream<StockSummary> _summary = widget.database.watchSummary();

  @override
  void initState() {
    super.initState();
    _refreshQuery();
  }

  void _refreshQuery() {
    _products = widget.database.watchProducts(
      search: _search,
      lowOnly: _lowOnly,
      category: _category,
    );
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailScreen(
          database: widget.database,
          productId: product.id,
        ),
      ),
    );
  }

  void _addProduct() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductFormScreen(database: widget.database),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mon stock')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un produit'),
      ),
      body: Column(
        children: [
          StreamBuilder<StockSummary>(
            stream: _summary,
            builder: (context, snapshot) {
              final summary = snapshot.data;
              if (summary == null) return const SizedBox.shrink();
              return _SummaryCard(
                summary: summary,
                onLowStockTap: () => setState(() {
                  _lowOnly = true;
                  _refreshQuery();
                }),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() {
                _search = value;
                _refreshQuery();
              }),
            ),
          ),
          SizedBox(
            height: 56,
            child: StreamBuilder<List<String>>(
              stream: _categories,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const [];
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    ChoiceChip(
                      label: const Text('Tous'),
                      selected: !_lowOnly && _category == null,
                      onSelected: (_) => setState(() {
                        _lowOnly = false;
                        _category = null;
                        _refreshQuery();
                      }),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Stock bas'),
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                      selected: _lowOnly,
                      onSelected: (selected) => setState(() {
                        _lowOnly = selected;
                        _refreshQuery();
                      }),
                    ),
                    for (final category in categories) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (selected) => setState(() {
                          _category = selected ? category : null;
                          _refreshQuery();
                        }),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _products,
              builder: (context, snapshot) {
                if (snapshot.error case final error?) {
                  return DataError(error: error);
                }
                final products = snapshot.data;
                if (products == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (products.isEmpty) {
                  return _EmptyMessage(
                    filtered:
                        _search.isNotEmpty || _lowOnly || _category != null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      leading: ProductThumbnail(
                        database: widget.database,
                        product: product,
                      ),
                      title: Text(
                        product.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('Prix : ${formatFcfa(product.salePrice)}'),
                      trailing: QuantityBadge(product: product),
                      onTap: () => _openProduct(product),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.onLowStockTap});

  final StockSummary summary;
  final VoidCallback onLowStockTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      clipBehavior: Clip.antiAlias,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Valeur du stock (prix d\'achat)',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
            Text(
              formatFcfa(summary.stockValue),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            Text(
              '${summary.productCount} produit${summary.productCount > 1 ? 's' : ''}',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
            if (summary.lowStockCount > 0) ...[
              const SizedBox(height: 8),
              Material(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onLowStockTap,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            summary.lowStockCount == 1
                                ? '1 produit est presque épuisé'
                                : '${summary.lowStockCount} produits sont presque épuisés',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.orange.shade900,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off : Icons.inventory_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'Aucun produit trouvé.'
                  : 'Aucun produit pour le moment.\n'
                        'Appuyez sur « Ajouter un produit » pour commencer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
