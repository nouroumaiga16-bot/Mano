import 'package:flutter/material.dart';

import 'customers/customers_screen.dart';
import 'data/database.dart';
import 'sales/sales_screen.dart';
import 'stock/stock_screen.dart';

/// Écran d'accueil avec la barre de menu du bas : Stock, Ventes, Clients.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          StockScreen(database: widget.database),
          SalesScreen(database: widget.database),
          CustomersScreen(database: widget.database),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Stock',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ventes',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clients',
          ),
        ],
      ),
    );
  }
}
