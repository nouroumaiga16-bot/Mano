import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../settings/shop_screen.dart';
import '../utils/format.dart';
import 'invoice_pdf.dart';
import 'payment.dart';

/// Facture d'une vente : aperçu, partage en PDF, annulation.
class SaleDetailScreen extends StatefulWidget {
  const SaleDetailScreen({
    super.key,
    required this.database,
    required this.saleId,
  });

  final AppDatabase database;
  final String saleId;

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _InvoiceData {
  const _InvoiceData(this.sale, this.items, this.shop);

  final Sale sale;
  final List<SaleItem> items;
  final ShopInfo shop;
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  AppDatabase get _db => widget.database;
  final _subscriptions = <StreamSubscription<Object?>>[];
  _InvoiceData? _data;

  /// Le PDF est préparé à l'avance : sur iPhone, le partage doit démarrer
  /// immédiatement après l'appui sur le bouton.
  Future<Uint8List>? _pdf;

  @override
  void initState() {
    super.initState();
    Sale? sale;
    List<SaleItem>? items;
    ShopInfo? shop;
    void update() {
      if (sale == null || items == null || shop == null) return;
      final data = _InvoiceData(sale!, items!, shop!);
      setState(() {
        _data = data;
        _pdf = buildInvoicePdf(
          sale: data.sale,
          items: data.items,
          shop: data.shop,
        );
      });
    }

    _subscriptions.addAll([
      _db.watchSale(widget.saleId).listen((value) {
        sale = value;
        update();
      }),
      _db.watchSaleItems(widget.saleId).listen((value) {
        items = value;
        update();
      }),
      _db.watchShopInfo().listen((value) {
        shop = value;
        update();
      }),
    ]);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  Future<void> _share(Sale sale) async {
    final pdf = _pdf;
    if (pdf == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final bytes = await pdf;
    final fileName = invoiceFileName(sale);
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(bytes, mimeType: 'application/pdf', name: fileName),
          ],
          fileNameOverrides: [fileName],
          downloadFallbackEnabled: true,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de partager la facture sur cet appareil.'),
        ),
      );
    }
  }

  Future<void> _cancel(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler cette vente ?'),
        content: const Text(
          'Les articles seront remis en stock. La facture restera dans la '
          'liste, marquée « Annulée ».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Annuler la vente'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.cancelSale(sale.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Vente annulée')));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final sale = data.sale;
    return Scaffold(
      appBar: AppBar(
        title: Text('Facture ${formatInvoiceNumber(sale.number)}'),
        actions: [
          if (!sale.cancelled)
            PopupMenuButton<void>(
              itemBuilder: (_) => [
                PopupMenuItem(
                  onTap: () => _cancel(sale),
                  child: const Text('Annuler la vente'),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (data.shop.name.isEmpty)
            Card(
              color: Colors.orange.shade100,
              child: ListTile(
                leading: Icon(Icons.storefront, color: Colors.orange.shade900),
                title: const Text(
                  'Ajoutez le nom de votre boutique pour qu\'il apparaisse '
                  'sur vos factures',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ShopScreen(database: _db),
                  ),
                ),
              ),
            ),
          if (sale.cancelled)
            Card(
              color: Colors.red.shade100,
              child: ListTile(
                leading: Icon(Icons.block, color: Colors.red.shade900),
                title: Text(
                  'Vente annulée : les articles ont été remis en stock.',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          _InvoicePreview(data: data),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            onPressed: () => _share(sale),
            icon: const Icon(Icons.share),
            label: const Text('Envoyer la facture (WhatsApp...)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(fontSize: 17),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aperçu à l'écran, proche du PDF envoyé au client.
class _InvoicePreview extends StatelessWidget {
  const _InvoicePreview({required this.data});

  final _InvoiceData data;

  @override
  Widget build(BuildContext context) {
    final sale = data.sale;
    final theme = Theme.of(context);
    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: bold ? theme.textTheme.titleMedium : null,
            ),
          ),
          Text(
            value,
            style: bold
                ? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : null,
          ),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.shop.logo case final logo?)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Image.memory(logo, height: 56, fit: BoxFit.contain),
                ),
              ),
            if (data.shop.name.isNotEmpty)
              Text(
                data.shop.name,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(formatDateTime(sale.createdAt)),
            if (sale.customerName != null || sale.customerPhone != null)
              Text(
                'Client : ${[?sale.customerName, if (sale.customerPhone case final phone?) formatPhone(phone)].join(' · ')}',
              ),
            const Divider(height: 24),
            for (final item in data.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${formatNumber(item.quantity)} × ${formatFcfa(item.unitPrice)}',
                          ),
                        ],
                      ),
                    ),
                    Text(formatFcfa(item.total)),
                  ],
                ),
              ),
            const Divider(height: 24),
            if (sale.discount > 0) ...[
              row('Sous-total', formatFcfa(sale.subtotal)),
              row('Remise', '− ${formatFcfa(sale.discount)}'),
            ],
            row('Total', formatFcfa(sale.total), bold: true),
            row('Paiement', paymentLabel(sale.paymentMethod)),
          ],
        ),
      ),
    );
  }
}
