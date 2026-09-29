import 'package:flutter/material.dart';

import 'customers/customers_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'data/database.dart';
import 'home/home_tab.dart';
import 'sales/new_sale_screen.dart';
import 'stock/stock_screen.dart';
import 'theme.dart';

/// Écran principal : Accueil, Stock, Clients, Bilan, et au centre de la
/// barre du bas un gros bouton « Nouvelle vente ».
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _newSale() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewSaleScreen(database: widget.database),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(
            database: widget.database,
            onNewSale: _newSale,
            onOpenTab: (destination) => setState(
              () => _tab = switch (destination) {
                HomeDestination.stock => 1,
                HomeDestination.customers => 2,
                HomeDestination.dashboard => 3,
              },
            ),
          ),
          StockScreen(database: widget.database),
          CustomersScreen(database: widget.database),
          DashboardScreen(database: widget.database),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        selected: _tab,
        onSelect: (index) => setState(() => _tab = index),
        onNewSale: _newSale,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.selected,
    required this.onSelect,
    required this.onNewSale,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onNewSale;

  @override
  Widget build(BuildContext context) {
    Widget item(int index, IconData icon, String label) => Expanded(
      child: _BarItem(
        icon: icon,
        label: label,
        selected: selected == index,
        onTap: () => onSelect(index),
      ),
    );

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: ManoColors.forest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              blurRadius: 16,
              color: Colors.black26,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            item(0, Icons.home_rounded, 'Accueil'),
            item(1, Icons.inventory_2_rounded, 'Stock'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Tooltip(
                message: 'Nouvelle vente',
                child: Material(
                  color: ManoColors.lime,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onNewSale,
                    child: const SizedBox.square(
                      dimension: 60,
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        color: ManoColors.forest,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            item(2, Icons.people_rounded, 'Clients'),
            item(3, Icons.bar_chart_rounded, 'Bilan'),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ManoColors.lime : Colors.white70;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
