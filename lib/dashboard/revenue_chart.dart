import 'package:flutter/material.dart';

import '../data/database.dart';
import '../utils/format.dart';

/// Histogramme simple (une seule série) : une colonne par jour ou par mois.
/// Toucher une colonne affiche sa valeur exacte au-dessus du graphique.
class RevenueChart extends StatefulWidget {
  const RevenueChart({super.key, required this.values, required this.byMonth});

  final Map<DateTime, int> values;
  final bool byMonth;

  @override
  State<RevenueChart> createState() => _RevenueChartState();
}

class _RevenueChartState extends State<RevenueChart> {
  DateTime? _selected;

  @override
  void didUpdateWidget(RevenueChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.values.containsKey(_selected)) _selected = null;
  }

  String _bucketLabel(DateTime date) => widget.byMonth
      ? '${monthName(date.month)} ${date.year}'
      : '${date.day} ${monthName(date.month).toLowerCase()}';

  /// Graduation « ronde » au-dessus du maximum : 1 ; 2 ; 2,5 ou 5 × 10^n.
  static int _niceMax(int max) {
    if (max <= 0) return 1000;
    var step = 1;
    while (step * 10 <= max) {
      step *= 10;
    }
    for (final factor in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      final candidate = (step * factor).round();
      if (candidate >= max) return candidate;
    }
    return step * 10;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: colors.onSurfaceVariant);
    final entries = widget.values.entries.toList();
    final top = _niceMax(
      entries.fold(0, (max, e) => e.value > max ? e.value : max),
    );
    final selected = _selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 20,
          child: Text(
            selected == null
                ? 'Touchez une colonne pour voir le montant'
                : '${_bucketLabel(selected)} : '
                      '${formatFcfa(widget.values[selected] ?? 0)}',
            style: selected == null
                ? muted
                : const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        Text(formatNumber(top), style: muted),
        SizedBox(
          height: 160,
          child: DecoratedBox(
            // Deux traits fins et discrets : le haut de l'échelle et la base.
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.outlineVariant, width: 1),
                bottom: BorderSide(color: colors.outlineVariant, width: 1),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final slot = constraints.maxWidth / entries.length;
                // Colonnes fines (24 px max) séparées par au moins 2 px.
                final barWidth = (slot - 2).clamp(2.0, 24.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final entry in entries)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(
                          () => _selected = _selected == entry.key
                              ? null
                              : entry.key,
                        ),
                        child: SizedBox(
                          width: slot,
                          height: constraints.maxHeight,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: barWidth,
                              height: constraints.maxHeight * entry.value / top,
                              decoration: BoxDecoration(
                                color: selected == null || selected == entry.key
                                    ? colors.primary
                                    : colors.primary.withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Repères sous la première, la colonne du milieu et la dernière.
        SizedBox(
          height: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 44.0;
              final slot = constraints.maxWidth / entries.length;
              return Stack(
                children: [
                  for (final index in {
                    0,
                    entries.length ~/ 2,
                    entries.length - 1,
                  })
                    Positioned(
                      left: (slot * index + slot / 2 - labelWidth / 2).clamp(
                        0.0,
                        constraints.maxWidth - labelWidth,
                      ),
                      width: labelWidth,
                      child: Text(
                        _axisLabel(entries[index].key),
                        style: muted,
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static const _shortMonths = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];

  String _axisLabel(DateTime date) =>
      widget.byMonth ? _shortMonths[date.month - 1] : '${date.day}';
}
