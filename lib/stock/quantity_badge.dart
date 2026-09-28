import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';

/// Pastille de quantité : verte (OK), orange (stock bas), rouge (épuisé).
class QuantityBadge extends StatelessWidget {
  const QuantityBadge({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final (
      Color background,
      Color foreground,
      String label,
    ) = product.isOutOfStock
        ? (Colors.red.shade100, Colors.red.shade900, 'Épuisé')
        : product.isLowStock
        ? (Colors.orange.shade100, Colors.orange.shade900, 'Stock bas')
        : (Colors.green.shade100, Colors.green.shade900, 'En stock');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatNumber(product.quantity),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: foreground,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: foreground)),
        ],
      ),
    );
  }
}
