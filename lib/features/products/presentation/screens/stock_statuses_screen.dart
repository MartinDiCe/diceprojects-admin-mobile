import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class StockStatusesScreen extends StatelessWidget {
  const StockStatusesScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Estados de stock',
    endpoint: '/v1/stock-statuses',
    icon: Icons.inventory_rounded,
    emptyTitle: 'Sin estados de stock',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
