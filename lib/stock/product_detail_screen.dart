import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';
import 'product_form_screen.dart';
import 'quantity_badge.dart';

/// Fiche d'un produit : prix, quantité, actions sur le stock et historique.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.database,
    required this.productId,
  });

  final AppDatabase database;
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  AppDatabase get database => widget.database;
  late final _product = database.watchProduct(widget.productId);
  late final _movements = database.watchMovements(widget.productId);

  Future<void> _addStock(Product product) async {
    final result = await showDialog<_QuantityResult>(
      context: context,
      builder: (_) => const _QuantityDialog(
        title: 'Ajouter du stock',
        label: 'Nombre d\'unités reçues',
        confirm: 'Ajouter',
      ),
    );
    if (result == null || result.quantity == 0) return;
    await database.addStock(product.id, result.quantity, note: result.note);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('+${formatNumber(result.quantity)} ajouté(s)')),
    );
  }

  Future<void> _correctQuantity(Product product) async {
    final result = await showDialog<_QuantityResult>(
      context: context,
      builder: (_) => _QuantityDialog(
        title: 'Corriger la quantité',
        label: 'Quantité réelle comptée',
        confirm: 'Corriger',
        initial: product.quantity,
        notePlaceholder: 'Ex : 2 cassés',
      ),
    );
    if (result == null) return;
    await database.setQuantity(product.id, result.quantity, note: result.note);
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce produit ?'),
        content: Text('« ${product.name} » ne sera plus dans votre stock.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await database.deleteProduct(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Produit supprimé')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: _product,
      builder: (context, snapshot) {
        final product = snapshot.data;
        if (product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
            actions: [
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ProductFormScreen(database: database, product: product),
                  ),
                ),
              ),
              PopupMenuButton<void>(
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => _delete(product),
                    child: const Text('Supprimer le produit'),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PhotoHeader(database: database, productId: product.id),
              _InfoCard(product: product),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _addStock(product),
                icon: const Icon(Icons.add_box),
                label: const Text('Ajouter du stock'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _correctQuantity(product),
                icon: const Icon(Icons.edit_note),
                label: const Text('Corriger la quantité'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
              const SizedBox(height: 24),
              Text('Historique', style: Theme.of(context).textTheme.titleLarge),
              _MovementHistory(movements: _movements),
            ],
          ),
        );
      },
    );
  }
}

/// Grande photo en haut de la fiche (rien s'il n'y a pas de photo).
class _PhotoHeader extends StatefulWidget {
  const _PhotoHeader({required this.database, required this.productId});

  final AppDatabase database;
  final String productId;

  @override
  State<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends State<_PhotoHeader> {
  late final _photo = widget.database.watchPhoto(widget.productId);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Uint8List?>(
      stream: _photo,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final profit = product.unitProfit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quantité en stock',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                QuantityBadge(product: product),
              ],
            ),
            const Divider(height: 24),
            if (product.category case final category?)
              _InfoRow('Catégorie', category),
            if (product.color case final color?) _InfoRow('Couleur', color),
            if (product.size case final size?) _InfoRow('Taille', size),
            _InfoRow('Prix de vente', formatFcfa(product.salePrice)),
            _InfoRow('Prix d\'achat', formatFcfa(product.purchasePrice)),
            _InfoRow(
              'Bénéfice par unité',
              formatFcfa(profit),
              color: profit < 0 ? Colors.red.shade800 : Colors.green.shade800,
            ),
            _InfoRow(
              'Valeur en stock',
              formatFcfa(product.purchasePrice * product.quantity),
            ),
            _InfoRow(
              'Alerte stock bas',
              'à ${formatNumber(product.lowStockThreshold)} ou moins',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _MovementHistory extends StatelessWidget {
  const _MovementHistory({required this.movements});

  final Stream<List<StockMovement>> movements;

  static String _label(MovementReason reason) => switch (reason) {
    MovementReason.initial => 'Stock de départ',
    MovementReason.restock => 'Stock ajouté',
    MovementReason.correction => 'Correction',
    MovementReason.sale => 'Vente',
    MovementReason.saleCancelled => 'Vente annulée',
  };

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StockMovement>>(
      stream: movements,
      builder: (context, snapshot) {
        final movements = snapshot.data ?? const [];
        if (movements.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Aucun mouvement pour le moment.'),
          );
        }
        return Column(
          children: [
            for (final m in movements)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_label(m.reason)),
                subtitle: Text(
                  [formatDateTime(m.createdAt), ?m.note].join(' · '),
                ),
                trailing: Text(
                  '${m.change > 0 ? '+' : ''}${formatNumber(m.change)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: m.change >= 0
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuantityResult {
  const _QuantityResult(this.quantity, this.note);

  final int quantity;
  final String? note;
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({
    required this.title,
    required this.label,
    required this.confirm,
    this.initial,
    this.notePlaceholder,
  });

  final String title;
  final String label;
  final String confirm;
  final int? initial;
  final String? notePlaceholder;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final _quantity = TextEditingController(
    text: widget.initial == null ? '' : formatNumber(widget.initial!),
  );
  final _note = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = parseNumber(_quantity.text);
    if (quantity == null) return;
    Navigator.pop(context, _QuantityResult(quantity, _note.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            decoration: InputDecoration(labelText: widget.label),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: 'Note (facultatif)',
              hintText: widget.notePlaceholder,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirm)),
      ],
    );
  }
}
