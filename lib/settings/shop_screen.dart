import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/database.dart';

/// Nom, téléphone et adresse de la boutique, affichés sur les factures.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  Uint8List? _logo;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.database.watchShopInfo().first.then((info) {
      if (!mounted) return;
      setState(() {
        _name.text = info.name;
        _phone.text = info.phone;
        _address.text = info.address;
        _logo = info.logo;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _logo = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir vos photos')),
      );
    }
  }

  Future<void> _save() async {
    await widget.database.saveShopInfo(
      ShopInfo(
        name: _name.text,
        phone: _phone.text,
        address: _address.text,
        logo: _logo,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Boutique enregistrée')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ma boutique')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Ces informations apparaissent en haut de vos factures.',
                ),
                const SizedBox(height: 16),
                _LogoPicker(
                  logo: _logo,
                  onPick: _pickLogo,
                  onRemove: () => setState(() => _logo = null),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom de la boutique',
                    hintText: 'Ex : Boutique Awa',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    hintText: 'Ex : 70 00 00 00',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Adresse ou quartier',
                    hintText: 'Ex : Ouagadougou, Gounghin',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: const Text('Enregistrer'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
    );
  }
}

class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.logo,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? logo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final logo = this.logo;
    return Row(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: logo != null
              ? Image.memory(logo, fit: BoxFit.contain)
              : Icon(Icons.storefront, size: 40, color: colors.outline),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.image),
                label: Text(
                  logo == null ? 'Ajouter un logo' : 'Changer le logo',
                ),
              ),
              if (logo != null)
                TextButton.icon(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Retirer le logo'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
