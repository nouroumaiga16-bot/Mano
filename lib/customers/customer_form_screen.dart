import 'package:flutter/material.dart';

import '../data/database.dart';

/// Formulaire pour créer un client, ou modifier [customer] s'il est fourni.
/// Renvoie l'identifiant du client enregistré.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({
    super.key,
    required this.database,
    this.customer,
    this.initialName = '',
  });

  final AppDatabase database;
  final Customer? customer;

  /// Nom déjà tapé dans une recherche, repris pour gagner du temps.
  final String initialName;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.customer?.name ?? widget.initialName,
  );
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _neighborhood = TextEditingController(
    text: widget.customer?.neighborhood,
  );
  late final _note = TextEditingController(text: widget.customer?.note);
  bool _saving = false;

  bool get _isEditing => widget.customer != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _neighborhood.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final db = widget.database;
    final String id;
    if (_isEditing) {
      id = widget.customer!.id;
      await db.updateCustomer(
        id,
        name: _name.text,
        phone: _phone.text,
        neighborhood: _neighborhood.text,
        note: _note.text,
      );
    } else {
      id = await db.addCustomer(
        name: _name.text,
        phone: _phone.text,
        neighborhood: _neighborhood.text,
        note: _note.text,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le client' : 'Nouveau client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: 'Nom du client',
                hintText: 'Ex : Aïcha Ouédraogo',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Donnez un nom au client'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone (facultatif)',
                hintText: 'Ex : 76 36 38 32',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _neighborhood,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Quartier (facultatif)',
                hintText: 'Ex : Larlé',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (facultatif)',
                hintText: 'Ex : paie en fin de mois, cliente fidèle',
              ),
            ),
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
