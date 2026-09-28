import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';

const _uuid = Uuid();

/// Un produit en vente dans la boutique.
///
/// Les identifiants sont des UUID (et non des numéros 1, 2, 3...) pour que la
/// future synchronisation en ligne ne mélange pas les produits de deux
/// téléphones. Un produit supprimé est seulement marqué `deleted` : il reste
/// ainsi visible dans les anciennes factures.
@DataClassName('Product')
class Products extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Prix en FCFA (nombre entier, pas de centimes).
  IntColumn get purchasePrice => integer()();
  IntColumn get salePrice => integer()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();

  /// Alerte quand la quantité descend à ce niveau ou en dessous.
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

enum MovementReason { initial, restock, correction, sale }

/// Historique de chaque entrée ou sortie de stock (le « cahier » du produit).
@DataClassName('StockMovement')
class StockMovements extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get productId => text().references(Products, #id)();

  /// Positif pour une entrée, négatif pour une sortie.
  IntColumn get change => integer()();
  TextColumn get reason => textEnum<MovementReason>()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

extension ProductStock on Product {
  bool get isOutOfStock => quantity <= 0;
  bool get isLowStock => quantity <= lowStockThreshold;
  int get unitProfit => salePrice - purchasePrice;
}

class StockSummary {
  const StockSummary({
    required this.productCount,
    required this.lowStockCount,
    required this.stockValue,
  });

  final int productCount;
  final int lowStockCount;

  /// Valeur du stock au prix d'achat.
  final int stockValue;
}

@DriftDatabase(tables: [Products, StockMovements])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'mano',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) async {
    final result = await super.transaction(action, requireNew: requireNew);
    // Sur le web, drift n'écrit pas le COMMIT dans IndexedDB : sans cette
    // requête, les données disparaissent au rechargement de la page.
    // Dans une transaction imbriquée, elle ne fait rien de plus.
    if (kIsWeb) await customStatement('SELECT 1');
    return result;
  }

  Expression<bool> _isLow() =>
      products.quantity.isSmallerOrEqual(products.lowStockThreshold);

  Stream<List<Product>> watchProducts({
    String search = '',
    bool lowOnly = false,
  }) {
    final query = select(products)..where((p) => p.deleted.equals(false));
    final term = search.trim().toLowerCase();
    if (term.isNotEmpty) {
      query.where((p) => p.name.lower().like('%$term%'));
    }
    if (lowOnly) {
      query.where((_) => _isLow());
    }
    query.orderBy([(p) => OrderingTerm(expression: p.name.lower())]);
    return query.watch();
  }

  Stream<Product?> watchProduct(String id) {
    return (select(
      products,
    )..where((p) => p.id.equals(id))).watchSingleOrNull();
  }

  Stream<StockSummary> watchSummary() {
    final count = products.id.count();
    final low = products.id.count(filter: _isLow());
    final value = (products.purchasePrice * products.quantity).sum();
    final query = selectOnly(products)
      ..addColumns([count, low, value])
      ..where(products.deleted.equals(false));
    return query.watchSingle().map(
      (row) => StockSummary(
        productCount: row.read(count) ?? 0,
        lowStockCount: row.read(low) ?? 0,
        stockValue: row.read(value) ?? 0,
      ),
    );
  }

  Stream<List<StockMovement>> watchMovements(String productId) {
    return (select(stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.rowId),
          ]))
        .watch();
  }

  Future<String> addProduct({
    required String name,
    required int purchasePrice,
    required int salePrice,
    required int quantity,
    required int lowStockThreshold,
  }) {
    return transaction(() async {
      final product = await into(products).insertReturning(
        ProductsCompanion.insert(
          name: name.trim(),
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          quantity: Value(quantity),
          lowStockThreshold: Value(lowStockThreshold),
        ),
      );
      if (quantity != 0) {
        await _recordMovement(product.id, quantity, MovementReason.initial);
      }
      return product.id;
    });
  }

  Future<void> updateProduct(
    String id, {
    required String name,
    required int purchasePrice,
    required int salePrice,
    required int lowStockThreshold,
  }) async {
    await (update(products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name.trim()),
        purchasePrice: Value(purchasePrice),
        salePrice: Value(salePrice),
        lowStockThreshold: Value(lowStockThreshold),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Réapprovisionnement : ajoute [amount] unités au stock.
  Future<void> addStock(String id, int amount, {String? note}) {
    return _changeQuantity(id, amount, MovementReason.restock, note);
  }

  /// Corrige la quantité après un comptage (casse, perte, erreur...).
  Future<void> setQuantity(String id, int newQuantity, {String? note}) {
    return transaction(() async {
      final product = await (select(
        products,
      )..where((p) => p.id.equals(id))).getSingle();
      final delta = newQuantity - product.quantity;
      if (delta != 0) {
        await _changeQuantity(id, delta, MovementReason.correction, note);
      }
    });
  }

  Future<void> deleteProduct(String id) async {
    await (update(products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _changeQuantity(
    String id,
    int delta,
    MovementReason reason,
    String? note,
  ) {
    return transaction(() async {
      await (update(products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion.custom(
          quantity: products.quantity + Constant(delta),
          updatedAt: Constant(DateTime.now()),
        ),
      );
      await _recordMovement(id, delta, reason, note: note);
    });
  }

  Future<void> _recordMovement(
    String productId,
    int change,
    MovementReason reason, {
    String? note,
  }) async {
    final trimmed = note?.trim();
    await into(stockMovements).insert(
      StockMovementsCompanion.insert(
        productId: productId,
        change: change,
        reason: reason,
        note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
      ),
    );
  }
}
