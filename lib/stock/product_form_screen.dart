import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';
import '../utils/format.dart';

const _defaultCategories = [
  'Sacs',
  'Pagnes',
  'Vêtements',
  'Chaussures',
  'Bijoux',
  'Cosmétiques',
  'Alimentation',
];

const _defaultColors = [
  'Noir',
  'Blanc',
  'Rouge',
  'Bleu',
  'Vert',
  'Jaune',
  'Orange',
  'Rose',
  'Violet',
  'Marron',
  'Beige',
  'Gris',
  'Doré',
  'Argenté',
  'Multicolore',
];

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
  late final TextEditingController _category;
  late final TextEditingController _color;
  late final TextEditingController _size;
  bool _saving = false;

  /// Photo affichée dans le formulaire, et si elle a été changée.
  Uint8List? _photo;
  bool _photoChanged = false;

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
    _category = TextEditingController(text: p?.category);
    _color = TextEditingController(text: p?.color);
    _size = TextEditingController(text: p?.size);
    if (p != null) {
      widget.database.watchPhoto(p.id).first.then((bytes) {
        if (mounted && !_photoChanged) setState(() => _photo = bytes);
      });
    }
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
    _category.dispose();
    _color.dispose();
    _size.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      parseNumber(value ?? '') == null ? 'Obligatoire' : null;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = bytes;
        _photoChanged = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'appareil photo')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = widget.database;
    final purchasePrice = parseNumber(_purchasePrice.text)!;
    final salePrice = parseNumber(_salePrice.text)!;
    final threshold = parseNumber(_threshold.text)!;
    final String id;
    if (_isEditing) {
      id = widget.product!.id;
      await db.updateProduct(
        id,
        name: _name.text,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        lowStockThreshold: threshold,
        category: _category.text,
        color: _color.text,
        size: _size.text,
      );
    } else {
      id = await db.addProduct(
        name: _name.text,
        purchasePrice: purchasePrice,
        salePrice: salePrice,
        quantity: parseNumber(_quantity.text) ?? 0,
        lowStockThreshold: threshold,
        category: _category.text,
        color: _color.text,
        size: _size.text,
      );
    }
    if (_photoChanged) await db.setPhoto(id, _photo);
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
            _PhotoPicker(
              photo: _photo,
              onPick: _pickPhoto,
              onRemove: () => setState(() {
                _photo = null;
                _photoChanged = true;
              }),
            ),
            const SizedBox(height: 16),
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
            _SuggestField(
              controller: _category,
              label: 'Catégorie (facultatif)',
              hint: 'Ex : Sacs',
              suggestions: widget.database.watchDistinct(
                widget.database.products.category,
              ),
              defaults: _defaultCategories,
            ),
            const SizedBox(height: 16),
            _SuggestField(
              controller: _color,
              label: 'Couleur (facultatif)',
              hint: 'Ex : Noir',
              suggestions: widget.database.watchDistinct(
                widget.database.products.color,
              ),
              defaults: _defaultColors,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _size,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Taille ou pointure (facultatif)',
                hintText: 'Ex : M, XL, 42',
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              Text(
                'Même produit dans une autre couleur ou taille ? Créez un '
                'produit à part pour chacune : chacune aura son propre stock.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
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

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? photo;
  final void Function(ImageSource source) onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = this.photo;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.square(
            dimension: 96,
            child: photo != null
                ? Image.memory(photo, fit: BoxFit.cover)
                : ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 40,
                      color: colors.outline,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Prendre une photo'),
              ),
              OutlinedButton.icon(
                onPressed: () => onPick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choisir une photo'),
              ),
              if (photo != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Retirer la photo'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Champ texte avec des suggestions à toucher (valeurs déjà utilisées en
/// premier, puis valeurs courantes).
class _SuggestField extends StatefulWidget {
  const _SuggestField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.suggestions,
    required this.defaults,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Stream<List<String>> suggestions;
  final List<String> defaults;

  @override
  State<_SuggestField> createState() => _SuggestFieldState();
}

class _SuggestFieldState extends State<_SuggestField> {
  late final Stream<List<String>> _suggestions = widget.suggestions;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
          ),
        ),
        if (_focus.hasFocus)
          StreamBuilder<List<String>>(
            stream: _suggestions,
            builder: (context, snapshot) {
              final typed = widget.controller.text.trim().toLowerCase();
              final seen = <String>{};
              final values = [
                ...?snapshot.data,
                ...widget.defaults,
              ].where((v) => seen.add(v.toLowerCase()));
              final matches = values
                  .where(
                    (v) =>
                        v.toLowerCase().contains(typed) &&
                        v.toLowerCase() != typed,
                  )
                  .take(8)
                  .toList();
              if (matches.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final value in matches)
                      ActionChip(
                        label: Text(value),
                        onPressed: () {
                          widget.controller.text = value;
                          _focus.unfocus();
                        },
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
