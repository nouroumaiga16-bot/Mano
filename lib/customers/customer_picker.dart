import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';
import 'customer_form_screen.dart';

/// Ouvre la liste des clients et renvoie celui qui a été choisi (ou créé).
Future<Customer?> pickCustomer(BuildContext context, AppDatabase database) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CustomerPicker(database: database),
  );
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker({required this.database});

  final AppDatabase database;

  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  late final _customers = widget.database.watchCustomers();
  String _search = '';

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(
          database: widget.database,
          initialName: _search.trim(),
        ),
      ),
    );
    if (id == null || !mounted) return;
    final created = await widget.database.watchCustomer(id).first;
    if (!mounted) return;
    Navigator.pop(context, created.customer);
  }

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
                hintText: 'Rechercher un client',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add)),
            title: const Text('Nouveau client'),
            onTap: _create,
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<CustomerWithBalance>>(
              stream: _customers,
              builder: (context, snapshot) {
                final all = snapshot.data;
                if (all == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = filterCustomers(all, _search);
                return ListView.builder(
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final entry = customers[index];
                    final customer = entry.customer;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(customer.name.characters.first),
                      ),
                      title: Text(customer.name),
                      subtitle: Text(
                        [
                          if (customer.phone case final phone?)
                            formatPhone(phone),
                          ?customer.neighborhood,
                        ].join(' · '),
                      ),
                      trailing: entry.balance > 0
                          ? Text(
                              'Doit ${formatFcfa(entry.balance)}',
                              style: TextStyle(color: Colors.red.shade800),
                            )
                          : null,
                      onTap: () => Navigator.pop(context, customer),
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

/// Filtre par nom, téléphone ou quartier (sans tenir compte des espaces
/// dans les numéros).
List<CustomerWithBalance> filterCustomers(
  List<CustomerWithBalance> customers,
  String search,
) {
  final term = search.trim().toLowerCase();
  if (term.isEmpty) return customers;
  final digits = term.replaceAll(RegExp(r'\D'), '');
  return customers.where((entry) {
    final c = entry.customer;
    return c.name.toLowerCase().contains(term) ||
        (c.neighborhood?.toLowerCase().contains(term) ?? false) ||
        (digits.isNotEmpty &&
            (c.phone?.replaceAll(RegExp(r'\D'), '').contains(digits) ?? false));
  }).toList();
}
