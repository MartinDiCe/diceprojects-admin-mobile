import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class PresentationTypesScreen extends StatelessWidget {
  const PresentationTypesScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Tipos de presentación',
    endpoint: '/v1/presentation-types',
    icon: Icons.view_in_ar_rounded,
    emptyTitle: 'Sin tipos de presentación',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
