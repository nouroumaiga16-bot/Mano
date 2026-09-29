import 'package:flutter/material.dart';

import '../customers/customer_picker.dart';
import '../data/database.dart';
import '../utils/format.dart';
import '../widgets/product_thumbnail.dart';
import 'payment.dart';
import 'sale_detail_screen.dart';

/// Une ligne du panier en cours.
class _CartLine {
  _CartLine(this.product) : unitPrice = product.salePrice;

  final Product product;
  int quantity = 1;
  int unitPrice;

  int get total => quantity * unitPrice;
  bool get exceedsStock => quantity > product.quantity;
}

/// Création d'une vente : panier, remise, client, mode de paiement.
class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _lines = <_CartLine>[];
  final _discount = TextEditingController();
  final _amountPaid = TextEditingController(text: '0');
  Customer? _customer;
  bool _credit = false;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _saving = false;

  int get _subtotal => _lines.fold(0, (sum, line) => sum + line.total);
  int get _discountValue => parseNumber(_discount.text) ?? 0;
  int get _total => _subtotal - _discountValue;
  bool get _discountTooBig => _discountValue > _subtotal;

  /// Payé maintenant : tout, ou l'avance saisie pour une vente à crédit.
  int get _paidNow => _credit ? parseNumber(_amountPaid.text) ?? 0 : _total;
  bool get _paidTooMuch => _credit && _paidNow >= _total && _total > 0;
  bool get _missingCustomer => _credit && _customer == null;
  bool get _canSave =>
      _lines.isNotEmpty &&
      !_discountTooBig &&
      !_paidTooMuch &&
      !_missingCustomer &&
      !_saving;

  @override
  void initState() {
    super.initState();
    _discount.addListener(() => setState(() {}));
    _amountPaid.addListener(() => setState(() {}));
    // On commence directement par choisir un produit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _addProduct());
  }

  @override
  void dispose() {
    _discount.dispose();
    _amountPaid.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductPicker(database: widget.database),
    );
    if (product == null) return;
    setState(() {
      final existing = _lines.where((l) => l.product.id == product.id);
      if (existing.isNotEmpty) {
        existing.first.quantity++;
      } else {
        _lines.add(_CartLine(product));
      }
    });
  }

  Future<void> _editNumber({
    required String title,
    required int initial,
    required void Function(int) onSaved,
    String? suffix,
  }) async {
    final controller = TextEditingController(text: formatNumber(initial));
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [ThousandsInputFormatter()],
          decoration: InputDecoration(suffixText: suffix),
          onSubmitted: (text) => Navigator.pop(context, parseNumber(text)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, parseNumber(controller.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) setState(() => onSaved(value));
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final saleId = await widget.database.createSale(
      lines: [
        for (final line in _lines)
          SaleLineInput(
            product: line.product,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
          ),
      ],
      discount: _discountValue,
      paymentMethod: _payment,
      customer: _customer,
      amountPaid: _paidNow,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Vente enregistrée')));
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            SaleDetailScreen(database: widget.database, saleId: saleId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle vente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_lines.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Le panier est vide.', textAlign: TextAlign.center),
            ),
          for (final line in _lines)
            _CartLineTile(
              line: line,
              onMinus: () => setState(() {
                if (line.quantity > 1) {
                  line.quantity--;
                } else {
                  _lines.remove(line);
                }
              }),
              onPlus: () => setState(() => line.quantity++),
              onEditQuantity: () => _editNumber(
                title: 'Quantité',
                initial: line.quantity,
                onSaved: (value) {
                  if (value == 0) {
                    _lines.remove(line);
                  } else {
                    line.quantity = value;
                  }
                },
              ),
              onEditPrice: () => _editNumber(
                title: 'Prix pour ${line.product.displayName}',
                initial: line.unitPrice,
                suffix: 'FCFA',
                onSaved: (value) => line.unitPrice = value,
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addProduct,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un article'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _discount,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsInputFormatter()],
            decoration: InputDecoration(
              labelText: 'Remise sur le total (facultatif)',
              suffixText: 'FCFA',
              errorText: _discountTooBig
                  ? 'La remise est plus grande que le total'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _credit ? 'Client' : 'Client (facultatif)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _CustomerTile(
            customer: _customer,
            missing: _missingCustomer,
            onPick: () async {
              final customer = await pickCustomer(context, widget.database);
              if (customer != null) setState(() => _customer = customer);
            },
            onClear: () => setState(() => _customer = null),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vente à crédit'),
            subtitle: const Text('Le client paiera le reste plus tard'),
            value: _credit,
            onChanged: (value) => setState(() => _credit = value),
          ),
          if (_credit) ...[
            TextField(
              controller: _amountPaid,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Montant payé maintenant',
                suffixText: 'FCFA',
                helperText: _paidTooMuch
                    ? null
                    : 'Reste à payer : ${formatFcfa(_total - _paidNow)}',
                errorText: _paidTooMuch
                    ? 'Tout est payé : désactivez « Vente à crédit »'
                    : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_credit || _paidNow > 0) ...[
            Text(
              _credit ? 'Paiement de l\'avance' : 'Paiement',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(paymentLabel(method)),
                    selected: _payment == method,
                    onSelected: (_) => setState(() => _payment = method),
                  ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_credit && !_paidTooMuch && _lines.isNotEmpty)
                Text(
                  'Payé ${formatFcfa(_paidNow)} · reste ${formatFcfa(_total - _paidNow)}',
                  style: TextStyle(color: Colors.red.shade800),
                )
              else if (_discountValue > 0 && !_discountTooBig)
                Text(
                  '${formatFcfa(_subtotal)} − remise ${formatFcfa(_discountValue)}',
                ),
              Row(
                children: [
                  Text('Total', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(
                    formatFcfa(_discountTooBig ? _subtotal : _total),
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: const Icon(Icons.check),
                label: const Text('Valider la vente'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.onMinus,
    required this.onPlus,
    required this.onEditQuantity,
    required this.onEditPrice,
  });

  final _CartLine line;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onEditQuantity;
  final VoidCallback onEditPrice;

  @override
  Widget build(BuildContext context) {
    final priceChanged = line.unitPrice != line.product.salePrice;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    line.product.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  formatFcfa(line.total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onEditPrice,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '${formatFcfa(line.unitPrice)} / unité',
                              style: TextStyle(
                                color: priceChanged
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                fontWeight: priceChanged
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Moins',
                  onPressed: onMinus,
                  icon: Icon(line.quantity > 1 ? Icons.remove : Icons.delete),
                ),
                InkWell(
                  onTap: onEditQuantity,
                  child: SizedBox(
                    width: 44,
                    child: Text(
                      formatNumber(line.quantity),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Plus',
                  onPressed: onPlus,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (line.exceedsStock)
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: Colors.orange.shade900,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      line.product.quantity <= 0
                          ? 'Stock épuisé selon Mano'
                          : 'Il n\'en reste que ${formatNumber(line.product.quantity)} en stock',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Liste des produits à ajouter au panier, avec recherche.
class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.database});

  final AppDatabase database;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  late Stream<List<Product>> _products = widget.database.watchProducts();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un produit',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(
                () => _products = widget.database.watchProducts(search: value),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: _products,
              builder: (context, snapshot) {
                final products = snapshot.data;
                if (products == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (products.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun produit. Ajoutez d\'abord vos produits '
                        'dans l\'onglet Stock.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ListTile(
                      leading: ProductThumbnail(
                        database: widget.database,
                        product: product,
                      ),
                      title: Text(product.displayName),
                      subtitle: Text(
                        '${formatFcfa(product.salePrice)} · '
                        'Stock : ${formatNumber(product.quantity)}',
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () => Navigator.pop(context, product),
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

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.missing,
    required this.onPick,
    required this.onClear,
  });

  final Customer? customer;
  final bool missing;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final customer = this.customer;
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: missing ? colors.error : colors.outline),
      ),
      child: customer == null
          ? ListTile(
              leading: const Icon(Icons.person_search),
              title: const Text('Choisir un client'),
              subtitle: missing
                  ? Text(
                      'Obligatoire pour une vente à crédit',
                      style: TextStyle(color: colors.error),
                    )
                  : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: onPick,
            )
          : ListTile(
              leading: CircleAvatar(
                child: Text(customer.name.characters.first),
              ),
              title: Text(customer.name),
              subtitle: customer.phone == null
                  ? null
                  : Text(formatPhone(customer.phone!)),
              onTap: onPick,
              trailing: IconButton(
                tooltip: 'Retirer le client',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              ),
            ),
    );
  }
}
