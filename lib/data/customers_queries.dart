part of 'database.dart';

/// Un client avec ce qu'il doit encore.
class CustomerWithBalance {
  const CustomerWithBalance(this.customer, this.balance);

  final Customer customer;

  /// Reste à payer en FCFA (0 si le client ne doit rien).
  final int balance;
}

/// Une ligne de l'historique d'un client : un achat ou un remboursement.
sealed class CustomerEvent {
  DateTime get date;
}

class PurchaseEvent extends CustomerEvent {
  PurchaseEvent(this.sale);

  final Sale sale;

  @override
  DateTime get date => sale.createdAt;
}

class PaymentEvent extends CustomerEvent {
  PaymentEvent(this.payment);

  final Payment payment;

  @override
  DateTime get date => payment.createdAt;
}

extension SaleCredit on Sale {
  /// Reste à payer sur cette vente au moment où elle a été faite.
  int get unpaid => cancelled ? 0 : total - amountPaid;
}

extension CustomersQueries on AppDatabase {
  /// Dette = reste à payer des ventes non annulées − remboursements.
  static const _balanceSql = '''
    COALESCE((SELECT SUM(s.total - s.amount_paid) FROM sales s
              WHERE s.customer_id = c.id AND s.cancelled = 0), 0)
    - COALESCE((SELECT SUM(p.amount) FROM payments p
                WHERE p.customer_id = c.id), 0)''';

  Stream<List<CustomerWithBalance>> watchCustomers() {
    return customSelect(
      'SELECT c.*, $_balanceSql AS balance FROM customers c '
      'WHERE c.deleted = 0 ORDER BY lower(c.name)',
      readsFrom: {customers, sales, payments},
    ).watch().map(
      (rows) => [
        for (final row in rows)
          CustomerWithBalance(
            customers.map(row.data),
            row.read<int>('balance'),
          ),
      ],
    );
  }

  Stream<CustomerWithBalance> watchCustomer(String id) {
    return customSelect(
      'SELECT c.*, $_balanceSql AS balance FROM customers c WHERE c.id = ?',
      variables: [Variable.withString(id)],
      readsFrom: {customers, sales, payments},
    ).watchSingle().map(
      (row) => CustomerWithBalance(
        customers.map(row.data),
        row.read<int>('balance'),
      ),
    );
  }

  /// Achats et remboursements du client, du plus récent au plus ancien.
  Stream<List<CustomerEvent>> watchCustomerHistory(String customerId) {
    // Requête vide qui se relance dès qu'une vente ou un paiement change.
    final changes = customSelect(
      'SELECT 1',
      readsFrom: {sales, payments},
    ).watch();
    return changes.asyncMap((_) async {
      final customerSales = await (select(
        sales,
      )..where((s) => s.customerId.equals(customerId))).get();
      final customerPayments = await (select(
        payments,
      )..where((p) => p.customerId.equals(customerId))).get();
      return <CustomerEvent>[
        for (final sale in customerSales) PurchaseEvent(sale),
        for (final payment in customerPayments) PaymentEvent(payment),
      ]..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  Future<String> addCustomer({
    required String name,
    String? phone,
    String? neighborhood,
    String? note,
  }) async {
    final customer = await into(customers).insertReturning(
      CustomersCompanion.insert(
        name: name.trim(),
        phone: Value(_clean(phone)),
        neighborhood: Value(_clean(neighborhood)),
        note: Value(_clean(note)),
      ),
    );
    return customer.id;
  }

  Future<void> updateCustomer(
    String id, {
    required String name,
    String? phone,
    String? neighborhood,
    String? note,
  }) async {
    await (update(customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name.trim()),
        phone: Value(_clean(phone)),
        neighborhood: Value(_clean(neighborhood)),
        note: Value(_clean(note)),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Le client disparaît de la liste mais reste sur ses anciennes factures.
  Future<void> deleteCustomer(String id) async {
    await (update(customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Enregistre un remboursement. Refusé s'il dépasse ce que doit le client.
  Future<void> addPayment({
    required String customerId,
    required int amount,
    required PaymentMethod method,
    String? note,
    DateTime? date,
  }) {
    return transaction(() async {
      final balance = (await watchCustomer(customerId).first).balance;
      if (amount <= 0 || amount > balance) {
        throw ArgumentError('Le montant doit être entre 1 et $balance.');
      }
      await into(payments).insert(
        PaymentsCompanion.insert(
          customerId: customerId,
          amount: amount,
          method: method,
          note: Value(_clean(note)),
          createdAt: date == null ? const Value.absent() : Value(date),
        ),
      );
    });
  }

  /// Migration v4 : crée un client pour chaque nom déjà saisi sur une vente,
  /// et relie ces ventes au client. Relancée, elle réutilise les clients
  /// déjà créés au lieu de les doubler.
  Future<void> _createCustomersFromPastSales() async {
    final rows = await customSelect(
      'SELECT DISTINCT customer_name, customer_phone FROM sales '
      'WHERE customer_name IS NOT NULL AND customer_id IS NULL',
    ).get();
    for (final row in rows) {
      final name = row.read<String>('customer_name');
      final phone = row.readNullable<String>('customer_phone');
      final existing = await customSelect(
        'SELECT id FROM customers WHERE name = ? AND phone IS ? LIMIT 1',
        variables: [Variable.withString(name), Variable(phone)],
      ).getSingleOrNull();
      final id = existing?.read<String>('id') ?? _uuid.v4();
      if (existing == null) {
        await customStatement(
          'INSERT INTO customers (id, name, phone) VALUES (?, ?, ?)',
          [id, name, phone],
        );
      }
      await customStatement(
        'UPDATE sales SET customer_id = ? '
        'WHERE customer_name = ? AND customer_phone IS ? '
        'AND customer_id IS NULL',
        [id, name, phone],
      );
    }
  }
}
