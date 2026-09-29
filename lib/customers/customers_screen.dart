import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';
import 'customer_picker.dart';

/// Fichier clients : liste, recherche, total des dettes.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final _customers = widget.database.watchCustomers();
  String _search = '';
  bool _debtorsOnly = false;

  void _open(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDetailScreen(
          database: widget.database,
          customerId: customer.id,
        ),
      ),
    );
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(database: widget.database),
      ),
    );
    if (id == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CustomerDetailScreen(database: widget.database, customerId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes clients')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: _create,
        icon: const Icon(Icons.person_add),
        label: const Text('Nouveau client'),
      ),
      body: StreamBuilder<List<CustomerWithBalance>>(
        stream: _customers,
        builder: (context, snapshot) {
          final all = snapshot.data;
          if (all == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final debtors = all.where((c) => c.balance > 0).toList();
          final totalDue = debtors.fold(0, (sum, c) => sum + c.balance);
          var customers = filterCustomers(all, _search);
          if (_debtorsOnly) {
            customers = customers.where((c) => c.balance > 0).toList();
          }
          return Column(
            children: [
              _DebtCard(total: totalDue, debtorCount: debtors.length),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Rechercher (nom, téléphone, quartier)',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Tous'),
                      selected: !_debtorsOnly,
                      onSelected: (_) => setState(() => _debtorsOnly = false),
                    ),
                    ChoiceChip(
                      label: const Text('Doivent de l\'argent'),
                      selected: _debtorsOnly,
                      onSelected: (_) => setState(() => _debtorsOnly = true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: customers.isEmpty
                    ? _EmptyCustomers(filtered: all.isNotEmpty)
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = customers[index];
                          final c = entry.customer;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(c.name.characters.first),
                            ),
                            title: Text(
                              c.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              [
                                if (c.phone case final phone?)
                                  formatPhone(phone),
                                ?c.neighborhood,
                              ].join(' · '),
                            ),
                            trailing: entry.balance > 0
                                ? _DebtBadge(balance: entry.balance)
                                : null,
                            onTap: () => _open(c),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.total, required this.debtorCount});

  final int total;
  final int debtorCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Argent à recevoir (crédits)',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
            Text(
              formatFcfa(total),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.onPrimaryContainer,
              ),
            ),
            Text(
              debtorCount == 0
                  ? 'Aucun client ne vous doit d\'argent'
                  : '$debtorCount client${debtorCount > 1 ? 's' : ''} '
                        'vous doi${debtorCount > 1 ? 'vent' : 't'} de l\'argent',
              style: TextStyle(color: colors.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtBadge extends StatelessWidget {
  const _DebtBadge({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatFcfa(balance),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red.shade900,
            ),
          ),
          Text(
            'à payer',
            style: TextStyle(fontSize: 11, color: Colors.red.shade900),
          ),
        ],
      ),
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers({required this.filtered});

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
              filtered ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'Aucun client trouvé.'
                  : 'Aucun client pour le moment.\n'
                        'Appuyez sur « Nouveau client » pour commencer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
