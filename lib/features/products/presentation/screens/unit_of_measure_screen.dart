import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class UnitOfMeasureScreen extends StatelessWidget {
  const UnitOfMeasureScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Unidades de medida',
    endpoint: '/v1/unit-of-measure',
    icon: Icons.straighten_rounded,
    emptyTitle: 'Sin unidades de medida',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
