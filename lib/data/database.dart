import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'database.g.dart';
part 'sales_queries.dart';
part 'customers_queries.dart';

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

  /// Caractéristiques facultatives. Une couleur = un produit à part, avec
  /// son propre stock (ex. « Sac · Noir » et « Sac · Marron »).
  TextColumn get color => text().nullable()();
  TextColumn get size => text().nullable()();
  TextColumn get category => text().nullable()();

  /// Alerte quand la quantité descend à ce niveau ou en dessous.
  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Photo d'un produit (JPEG réduit), à part pour ne pas alourdir les listes.
@DataClassName('ProductPhoto')
class ProductPhotos extends Table {
  TextColumn get productId => text().references(Products, #id)();
  BlobColumn get bytes => blob()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {productId};
}

enum MovementReason { initial, restock, correction, sale, saleCancelled }

/// Historique de chaque entrée ou sortie de stock (le « cahier » du produit).
@DataClassName('StockMovement')
class StockMovements extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get productId => text().references(Products, #id)();

  /// Positif pour une entrée, négatif pour une sortie.
  IntColumn get change => integer()();
  TextColumn get reason => textEnum<MovementReason>()();
  TextColumn get note => text().nullable()();

  /// Vente à l'origine du mouvement (ventes et annulations seulement).
  TextColumn get saleId => text().nullable().references(Sales, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

enum PaymentMethod { cash, orangeMoney, moovMoney, wave }

/// Un client du fichier clients.
@DataClassName('Customer')
class Customers extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();

  /// Quartier (ex. Larlé, Gounghin).
  TextColumn get neighborhood => text().nullable()();

  /// Note libre : « paie en fin de mois », « cliente fidèle »...
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Un remboursement : argent reçu d'un client pour réduire sa dette.
@DataClassName('Payment')
class Payments extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get customerId => text().references(Customers, #id)();
  IntColumn get amount => integer()();
  TextColumn get method => textEnum<PaymentMethod>()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une vente, qui sert aussi de facture.
@DataClassName('Sale')
class Sales extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();

  /// Numéro de facture lisible : 1, 2, 3... (affiché « N° 0001 »).
  IntColumn get number => integer()();

  /// Client du fichier clients (obligatoire pour une vente à crédit).
  TextColumn get customerId => text().nullable().references(Customers, #id)();

  /// Nom et téléphone recopiés au moment de la vente, pour la facture.
  TextColumn get customerName => text().nullable()();
  TextColumn get customerPhone => text().nullable()();

  /// Somme des lignes, avant remise.
  IntColumn get subtotal => integer()();

  /// Remise sur le total, en FCFA.
  IntColumn get discount => integer().withDefault(const Constant(0))();
  IntColumn get total => integer()();
  TextColumn get paymentMethod => textEnum<PaymentMethod>()();

  /// Payé au moment de la vente. Moins que le total = vente à crédit ;
  /// le reste est dû par le client (voir [Payments] pour les remboursements).
  IntColumn get amountPaid => integer()();

  /// Une vente annulée remet les articles en stock mais reste visible.
  BoolColumn get cancelled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Une ligne de facture. Le nom et les prix sont recopiés au moment de la
/// vente : la facture ne change pas si le produit est modifié plus tard.
@DataClassName('SaleItem')
class SaleItems extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();
  TextColumn get saleId => text().references(Sales, #id)();
  TextColumn get productId => text().references(Products, #id)();
  TextColumn get productName => text()();
  IntColumn get quantity => integer()();
  IntColumn get unitPrice => integer()();

  /// Prix d'achat au moment de la vente, pour calculer le bénéfice.
  IntColumn get purchasePrice => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Réglages simples (nom de la boutique, téléphone...), sous forme clé/valeur.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

extension ProductStock on Product {
  /// « Sac Louis Vuitton · Noir · Taille 42 »
  String get displayName =>
      [name, ?color, if (size != null) 'Taille $size'].join(' · ');

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

@DriftDatabase(
  tables: [
    Products,
    ProductPhotos,
    StockMovements,
    Sales,
    SaleItems,
    Settings,
    Customers,
    Payments,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(sales);
        await m.createTable(saleItems);
        await m.createTable(settings);
        await m.addColumn(stockMovements, stockMovements.saleId);
      }
      if (from < 3) {
        await m.addColumn(products, products.color);
        await m.addColumn(products, products.size);
        await m.addColumn(products, products.category);
        await m.createTable(productPhotos);
      }
      if (from < 4) {
        await m.createTable(customers);
        await m.createTable(payments);
        // Une base v1 vient de recevoir la table sales complète (étape 2).
        if (from >= 2) await m.addColumn(sales, sales.customerId);
        await _createCustomersFromPastSales();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
    String? category,
  }) {
    final query = select(products)..where((p) => p.deleted.equals(false));
    final term = search.trim().toLowerCase();
    if (term.isNotEmpty) {
      final pattern = '%$term%';
      query.where(
        (p) =>
            p.name.lower().like(pattern) |
            p.color.lower().like(pattern) |
            p.size.lower().like(pattern) |
            p.category.lower().like(pattern),
      );
    }
    if (lowOnly) {
      query.where((_) => _isLow());
    }
    if (category != null) {
      query.where((p) => p.category.equals(category));
    }
    query.orderBy([(p) => OrderingTerm(expression: p.name.lower())]);
    return query.watch();
  }

  /// Valeurs déjà utilisées (catégories, couleurs...), pour les suggestions.
  Stream<List<String>> watchDistinct(GeneratedColumn<String> column) {
    final query = selectOnly(products, distinct: true)
      ..addColumns([column])
      ..where(products.deleted.equals(false) & column.isNotNull())
      ..orderBy([OrderingTerm(expression: column.lower())]);
    return query.map((row) => row.read(column)!).watch();
  }

  Stream<Uint8List?> watchPhoto(String productId) {
    return (select(productPhotos)..where((p) => p.productId.equals(productId)))
        .map((photo) => photo.bytes)
        .watchSingleOrNull();
  }

  /// Enregistre la photo du produit, ou la supprime si [bytes] est null.
  Future<void> setPhoto(String productId, Uint8List? bytes) async {
    if (bytes == null) {
      await (delete(
        productPhotos,
      )..where((p) => p.productId.equals(productId))).go();
    } else {
      await into(productPhotos).insertOnConflictUpdate(
        ProductPhotosCompanion.insert(
          productId: productId,
          bytes: bytes,
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
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
    String? color,
    String? size,
    String? category,
  }) {
    return transaction(() async {
      final product = await into(products).insertReturning(
        ProductsCompanion.insert(
          name: name.trim(),
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          quantity: Value(quantity),
          lowStockThreshold: Value(lowStockThreshold),
          color: Value(_clean(color)),
          size: Value(_clean(size)),
          category: Value(_clean(category)),
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
    String? color,
    String? size,
    String? category,
  }) async {
    await (update(products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name.trim()),
        purchasePrice: Value(purchasePrice),
        salePrice: Value(salePrice),
        lowStockThreshold: Value(lowStockThreshold),
        color: Value(_clean(color)),
        size: Value(_clean(size)),
        category: Value(_clean(category)),
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
    String? note, {
    String? saleId,
  }) {
    return transaction(() async {
      await (update(products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion.custom(
          quantity: products.quantity + Constant(delta),
          updatedAt: Constant(DateTime.now()),
        ),
      );
      await _recordMovement(id, delta, reason, note: note, saleId: saleId);
    });
  }

  Future<void> _recordMovement(
    String productId,
    int change,
    MovementReason reason, {
    String? note,
    String? saleId,
  }) async {
    final trimmed = note?.trim();
    await into(stockMovements).insert(
      StockMovementsCompanion.insert(
        productId: productId,
        change: change,
        reason: reason,
        note: Value(trimmed == null || trimmed.isEmpty ? null : trimmed),
        saleId: Value(saleId),
      ),
    );
  }
}
