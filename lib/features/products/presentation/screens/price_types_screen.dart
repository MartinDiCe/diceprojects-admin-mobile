import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class PriceTypesScreen extends StatelessWidget {
  const PriceTypesScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Tipos de precio',
    endpoint: '/v1/price-types',
    icon: Icons.price_change_rounded,
    emptyTitle: 'Sin tipos de precio',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
