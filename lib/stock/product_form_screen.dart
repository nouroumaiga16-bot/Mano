import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';

/// Formulaire pour créer un produit, ou modifier [product] s'il est fourni.
class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.database, this.product});

  final AppDatabase database;
  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _quantity;
  late final TextEditingController _threshold;
  bool _saving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name);
    _purchasePrice = TextEditingController(
      text: p == null ? '' : formatNumber(p.purchasePrice),
    );
    _salePrice = TextEditingController(
      text: p == null ? '' : formatNumber(p.salePrice),
    );
    _quantity = TextEditingController();
    _threshold = TextEditingController(
      text: formatNumber(p?.lowStockThreshold ?? 5),
    );
    // Met à jour le bénéfice affiché à chaque frappe.
    _purchasePrice.addListener(_onPriceChanged);
    _salePrice.addListener(_onPriceChanged);
  }

  void _onPriceChanged() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _purchasePrice.dispose();
    _salePrice.dispose();
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      parseNumber(value ?? '') == null ? 'Obligatoire' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = widget.database;
    final purchasePrice = parseNumber(_purchasePrice.text)!;
    final salePrice = parseNumber(_salePrice.text)!;
    final threshold = parseNumber(_threshold.text)!;
    if (_isEditing) {
      await db.updateProduct(
        widget.product!.id,
        name: _name.text,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        lowStockThreshold: threshold,
      );
    } else {
      await db.addProduct(
        name: _name.text,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        quantity: parseNumber(_quantity.text) ?? 0,
        lowStockThreshold: threshold,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? 'Produit modifié' : 'Produit ajouté'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final purchase = parseNumber(_purchasePrice.text);
    final sale = parseNumber(_salePrice.text);
    final profit = purchase != null && sale != null ? sale - purchase : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Nouveau produit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Nom du produit',
                hintText: 'Ex : Savon Kabakrou',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Donnez un nom au produit'
                  : null,
            ),
            const SizedBox(height: 8),
            _NumberField(
              controller: _purchasePrice,
              label: 'Prix d\'achat (par unité)',
              suffix: 'FCFA',
              validator: _required,
            ),
            const SizedBox(height: 16),
            _NumberField(
              controller: _salePrice,
              label: 'Prix de vente (par unité)',
              suffix: 'FCFA',
              validator: _required,
            ),
            _ProfitHint(profit: profit),
            const SizedBox(height: 16),
            if (!_isEditing) ...[
              _NumberField(
                controller: _quantity,
                label: 'Quantité en stock',
                helper: 'Combien en avez-vous maintenant ? (0 si vide)',
              ),
              const SizedBox(height: 16),
            ],
            _NumberField(
              controller: _threshold,
              label: 'Alerte stock bas à partir de',
              helper: 'Mano vous prévient quand il en reste ce nombre ou moins',
              validator: _required,
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              Text(
                'Pour changer la quantité, utilisez « Ajouter du stock » ou '
                '« Corriger la quantité » sur la fiche du produit.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('Enregistrer'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.suffix,
    this.helper,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? helper;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsInputFormatter()],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        helperText: helper,
        helperMaxLines: 2,
      ),
      validator: validator,
    );
  }
}

class _ProfitHint extends StatelessWidget {
  const _ProfitHint({required this.profit});

  final int? profit;

  @override
  Widget build(BuildContext context) {
    final profit = this.profit;
    if (profit == null) return const SizedBox.shrink();
    final negative = profit < 0;
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(
        negative
            ? 'Attention : vous perdez ${formatFcfa(-profit)} par unité'
            : 'Bénéfice : ${formatFcfa(profit)} par unité',
        style: TextStyle(
          color: negative ? Colors.red.shade800 : Colors.green.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
