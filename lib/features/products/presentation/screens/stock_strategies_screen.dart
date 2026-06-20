import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class StockStrategiesScreen extends StatelessWidget {
  const StockStrategiesScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Estrategias de stock',
    endpoint: '/v1/stock-strategies',
    icon: Icons.account_tree_rounded,
    emptyTitle: 'Sin estrategias de stock',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
