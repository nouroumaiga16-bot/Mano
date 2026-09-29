part of 'database.dart';

/// Une ligne du panier, avant l'enregistrement de la vente.
class SaleLineInput {
  const SaleLineInput({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  final Product product;
  final int quantity;
  final int unitPrice;

  int get total => quantity * unitPrice;
}

class ShopInfo {
  const ShopInfo({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.logo,
  });

  final String name;
  final String phone;
  final String address;

  /// Logo de la boutique (image réduite), affiché sur les factures.
  final Uint8List? logo;

  bool get isEmpty => name.isEmpty && phone.isEmpty && address.isEmpty;
}

class DaySales {
  const DaySales({required this.count, required this.total});

  final int count;
  final int total;
}

extension SaleItemTotal on SaleItem {
  int get total => quantity * unitPrice;
}

/// « N° 0007 »
String formatInvoiceNumber(int number) =>
    'N° ${number.toString().padLeft(4, '0')}';

extension SalesQueries on AppDatabase {
  /// Enregistre la vente, baisse le stock et renvoie l'identifiant de la vente.
  Future<String> createSale({
    required List<SaleLineInput> lines,
    required PaymentMethod paymentMethod,
    int discount = 0,
    String? customerName,
    String? customerPhone,
  }) {
    if (lines.isEmpty) {
      throw ArgumentError('Une vente doit contenir au moins un article.');
    }
    final subtotal = lines.fold(0, (sum, line) => sum + line.total);
    if (discount < 0 || discount > subtotal) {
      throw ArgumentError('La remise doit être entre 0 et le total.');
    }
    final total = subtotal - discount;

    return transaction(() async {
      final maxNumber = sales.number.max();
      final last = await (selectOnly(
        sales,
      )..addColumns([maxNumber])).map((row) => row.read(maxNumber)).getSingle();
      final number = (last ?? 0) + 1;

      final sale = await into(sales).insertReturning(
        SalesCompanion.insert(
          number: number,
          customerName: Value(_clean(customerName)),
          customerPhone: Value(_clean(customerPhone)),
          subtotal: subtotal,
          discount: Value(discount),
          total: total,
          paymentMethod: paymentMethod,
          amountPaid: total,
        ),
      );

      for (final line in lines) {
        await into(saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: sale.id,
            productId: line.product.id,
            productName: line.product.displayName,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            purchasePrice: line.product.purchasePrice,
          ),
        );
        await _changeQuantity(
          line.product.id,
          -line.quantity,
          MovementReason.sale,
          'Facture ${formatInvoiceNumber(number)}',
          saleId: sale.id,
        );
      }
      return sale.id;
    });
  }

  /// Annule une vente : les articles reviennent en stock.
  Future<void> cancelSale(String saleId) {
    return transaction(() async {
      final sale = await (select(
        sales,
      )..where((s) => s.id.equals(saleId))).getSingle();
      if (sale.cancelled) return;

      await (update(sales)..where((s) => s.id.equals(saleId))).write(
        SalesCompanion(
          cancelled: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      );
      final items = await (select(
        saleItems,
      )..where((i) => i.saleId.equals(saleId))).get();
      for (final item in items) {
        await _changeQuantity(
          item.productId,
          item.quantity,
          MovementReason.saleCancelled,
          'Facture ${formatInvoiceNumber(sale.number)} annulée',
          saleId: saleId,
        );
      }
    });
  }

  Stream<List<Sale>> watchSales() {
    return (select(
      sales,
    )..orderBy([(s) => OrderingTerm.desc(s.number)])).watch();
  }

  Stream<Sale> watchSale(String id) {
    return (select(sales)..where((s) => s.id.equals(id))).watchSingle();
  }

  Stream<List<SaleItem>> watchSaleItems(String saleId) {
    return (select(saleItems)
          ..where((i) => i.saleId.equals(saleId))
          ..orderBy([(i) => OrderingTerm(expression: i.rowId)]))
        .watch();
  }

  /// Total des ventes (non annulées) du jour contenant [day].
  Stream<DaySales> watchDaySales(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final count = sales.id.count();
    final total = sales.total.sum();
    final query = selectOnly(sales)
      ..addColumns([count, total])
      ..where(
        sales.cancelled.equals(false) &
            sales.createdAt.isBiggerOrEqualValue(start) &
            sales.createdAt.isSmallerThanValue(end),
      );
    return query.watchSingle().map(
      (row) =>
          DaySales(count: row.read(count) ?? 0, total: row.read(total) ?? 0),
    );
  }

  static const _shopName = 'shop.name';
  static const _shopPhone = 'shop.phone';
  static const _shopAddress = 'shop.address';
  static const _shopLogo = 'shop.logo';

  Stream<ShopInfo> watchShopInfo() {
    return select(settings).watch().map((rows) {
      final values = {for (final row in rows) row.key: row.value};
      return ShopInfo(
        name: values[_shopName] ?? '',
        phone: values[_shopPhone] ?? '',
        address: values[_shopAddress] ?? '',
        logo: switch (values[_shopLogo]) {
          final encoded? => base64Decode(encoded),
          null => null,
        },
      );
    });
  }

  Future<void> saveShopInfo(ShopInfo info) {
    return transaction(() async {
      for (final entry in {
        _shopName: info.name,
        _shopPhone: info.phone,
        _shopAddress: info.address,
      }.entries) {
        await into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: entry.key, value: entry.value.trim()),
        );
      }
      // Le logo est gardé en texte (base64) avec les autres réglages.
      final logo = info.logo;
      if (logo == null) {
        await (delete(settings)..where((s) => s.key.equals(_shopLogo))).go();
      } else {
        await into(settings).insertOnConflictUpdate(
          SettingsCompanion.insert(key: _shopLogo, value: base64Encode(logo)),
        );
      }
    });
  }
}

String? _clean(String? text) {
  final trimmed = text?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
