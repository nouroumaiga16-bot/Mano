import 'package:flutter/material.dart';

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

  Future<void> _save() async {
    await widget.database.saveShopInfo(
      ShopInfo(name: _name.text, phone: _phone.text, address: _address.text),
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
