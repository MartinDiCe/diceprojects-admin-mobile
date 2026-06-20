import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class ProductStatusesScreen extends StatelessWidget {
  const ProductStatusesScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Estados de producto',
    endpoint: '/v1/product-statuses',
    icon: Icons.flag_rounded,
    emptyTitle: 'Sin estados de producto',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
