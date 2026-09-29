import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/database.dart';

/// Photo du produit, ou sa première lettre s'il n'a pas de photo.
class ProductThumbnail extends StatefulWidget {
  const ProductThumbnail({
    super.key,
    required this.database,
    required this.product,
    this.size = 48,
  });

  final AppDatabase database;
  final Product product;
  final double size;

  @override
  State<ProductThumbnail> createState() => _ProductThumbnailState();
}

class _ProductThumbnailState extends State<ProductThumbnail> {
  late Stream<Uint8List?> _photo = widget.database.watchPhoto(
    widget.product.id,
  );

  @override
  void didUpdateWidget(ProductThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _photo = widget.database.watchPhoto(widget.product.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<Uint8List?>(
      stream: _photo,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.size / 6),
          child: SizedBox.square(
            dimension: widget.size,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
                : ColoredBox(
                    color: colors.secondaryContainer,
                    child: Center(
                      child: Text(
                        widget.product.name.characters.first.toUpperCase(),
                        style: TextStyle(
                          fontSize: widget.size * 0.45,
                          fontWeight: FontWeight.bold,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
