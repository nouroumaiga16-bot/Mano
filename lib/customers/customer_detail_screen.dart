import 'package:flutter/material.dart';

import '../data/database.dart';
import '../sales/payment.dart';
import '../sales/sale_detail_screen.dart';
import '../utils/contact.dart';
import '../utils/format.dart';
import 'customer_form_screen.dart';

/// Fiche d'un client : coordonnées, dette, remboursements, historique.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.database,
    required this.customerId,
  });

  final AppDatabase database;
  final String customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  AppDatabase get _db => widget.database;
  late final _customer = _db.watchCustomer(widget.customerId);
  late final _history = _db.watchCustomerHistory(widget.customerId);

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addPayment(CustomerWithBalance entry) async {
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(balance: entry.balance),
    );
    if (result == null) return;
    await _db.addPayment(
      customerId: entry.customer.id,
      amount: result.amount,
      method: result.method,
      note: result.note,
    );
    if (!mounted) return;
    _snack('Paiement de ${formatFcfa(result.amount)} enregistré');
  }

  Future<void> _remind(CustomerWithBalance entry) async {
    final shop = await _db.watchShopInfo().first;
    final uri = whatsappUri(
      entry.customer.phone ?? '',
      reminderMessage(
        customerName: entry.customer.name,
        balance: entry.balance,
        shopName: shop.name,
      ),
    );
    if (uri == null || !await openUri(uri)) {
      if (mounted) _snack('Impossible d\'ouvrir WhatsApp pour ce numéro');
    }
  }

  Future<void> _call(String phone) async {
    if (!await openUri(callUri(phone)) && mounted) {
      _snack('Impossible d\'appeler ce numéro');
    }
  }

  Future<void> _delete(CustomerWithBalance entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: Text(
          entry.balance > 0
              ? '${entry.customer.name} vous doit encore '
                    '${formatFcfa(entry.balance)}. Supprimer quand même ?'
              : '${entry.customer.name} ne sera plus dans vos clients. '
                    'Ses anciennes factures restent.',
        ),
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
    await _db.deleteCustomer(entry.customer.id);
    if (!mounted) return;
    _snack('Client supprimé');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CustomerWithBalance>(
      stream: _customer,
      builder: (context, snapshot) {
        final entry = snapshot.data;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final customer = entry.customer;
        final phone = customer.phone;
        final canWhatsapp = phone != null && internationalPhone(phone) != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(customer.name),
            actions: [
              IconButton(
                tooltip: 'Modifier',
                icon: const Icon(Icons.edit),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CustomerFormScreen(database: _db, customer: customer),
                  ),
                ),
              ),
              PopupMenuButton<void>(
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: () => _delete(entry),
                    child: const Text('Supprimer le client'),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(balance: entry.balance),
              const SizedBox(height: 12),
              if (entry.balance > 0) ...[
                FilledButton.icon(
                  onPressed: () => _addPayment(entry),
                  icon: const Icon(Icons.payments),
                  label: const Text('Enregistrer un paiement'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 8),
                if (canWhatsapp)
                  OutlinedButton.icon(
                    onPressed: () => _remind(entry),
                    icon: const Icon(Icons.chat),
                    label: const Text('Rappeler par WhatsApp'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              Card(
                child: Column(
                  children: [
                    if (phone != null)
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text(formatPhone(phone)),
                        trailing: IconButton(
                          tooltip: 'Appeler',
                          icon: const Icon(Icons.call),
                          onPressed: () => _call(phone),
                        ),
                      ),
                    if (customer.neighborhood case final neighborhood?)
                      ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(neighborhood),
                      ),
                    if (customer.note case final note?)
                      ListTile(
                        leading: const Icon(Icons.sticky_note_2_outlined),
                        title: Text(note),
                      ),
                    if (phone == null &&
                        customer.neighborhood == null &&
                        customer.note == null)
                      const ListTile(
                        leading: Icon(Icons.info_outline),
                        title: Text('Pas de téléphone ni de quartier'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text('Historique', style: Theme.of(context).textTheme.titleLarge),
              StreamBuilder<List<CustomerEvent>>(
                stream: _history,
                builder: (context, snapshot) {
                  final events = snapshot.data ?? const [];
                  if (events.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('Aucun achat pour le moment.'),
                    );
                  }
                  return Column(
                    children: [
                      for (final event in events)
                        switch (event) {
                          PurchaseEvent(:final sale) => _PurchaseTile(
                            sale: sale,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => SaleDetailScreen(
                                  database: _db,
                                  saleId: sale.id,
                                ),
                              ),
                            ),
                          ),
                          PaymentEvent(:final payment) => _PaymentTile(
                            payment: payment,
                          ),
                        },
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    final owes = balance > 0;
    final (background, foreground) = owes
        ? (Colors.red.shade50, Colors.red.shade900)
        : (Colors.green.shade50, Colors.green.shade900);
    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              owes ? 'Reste à payer' : 'Ne doit rien',
              style: TextStyle(color: foreground),
            ),
            if (owes)
              Text(
                formatFcfa(balance),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: foreground),
              ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseTile extends StatelessWidget {
  const _PurchaseTile({required this.sale, required this.onTap});

  final Sale sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = sale.cancelled
        ? 'Annulée'
        : sale.unpaid > 0
        ? 'Payé ${formatFcfa(sale.amountPaid)} · reste ${formatFcfa(sale.unpaid)}'
        : 'Payé';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: const Icon(Icons.shopping_bag_outlined),
      title: Text('Achat · Facture ${formatInvoiceNumber(sale.number)}'),
      subtitle: Text('${formatDateTime(sale.createdAt)}\n$subtitle'),
      isThreeLine: true,
      trailing: Text(
        formatFcfa(sale.total),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          decoration: sale.cancelled ? TextDecoration.lineThrough : null,
          color: sale.unpaid > 0 ? Colors.red.shade800 : null,
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.payments_outlined, color: Colors.green.shade800),
      title: Text('Paiement reçu · ${paymentLabel(payment.method)}'),
      subtitle: Text(
        [formatDateTime(payment.createdAt), ?payment.note].join('\n'),
      ),
      trailing: Text(
        '+${formatFcfa(payment.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green.shade800,
        ),
      ),
    );
  }
}

class _PaymentInput {
  const _PaymentInput(this.amount, this.method, this.note);

  final int amount;
  final PaymentMethod method;
  final String? note;
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.balance});

  final int balance;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final _amount = TextEditingController(
    text: formatNumber(widget.balance),
  );
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  int get _value => parseNumber(_amount.text) ?? 0;
  bool get _tooMuch => _value > widget.balance;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _value > 0 && !_tooMuch;
    return AlertDialog(
      title: const Text('Paiement reçu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Il doit ${formatFcfa(widget.balance)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Montant reçu',
                suffixText: 'FCFA',
                errorText: _tooMuch ? 'Plus que ce qu\'il doit' : null,
                helperText: valid && _value < widget.balance
                    ? 'Il restera ${formatFcfa(widget.balance - _value)}'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final method in PaymentMethod.values)
                  ChoiceChip(
                    label: Text(paymentLabel(method)),
                    selected: _method == method,
                    onSelected: (_) => setState(() => _method = method),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (facultatif)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  _PaymentInput(_value, _method, _note.text),
                )
              : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
