import 'package:app_diceprojects_admin/features/products/presentation/screens/catalog_master_screen.dart';
import 'package:flutter/material.dart';

class PublicationChannelsScreen extends StatelessWidget {
  const PublicationChannelsScreen({super.key});

  static const _config = CatalogMasterConfig(
    title: 'Canales de publicación',
    endpoint: '/v1/publication-channels',
    icon: Icons.public_rounded,
    emptyTitle: 'Sin canales de publicación',
  );

  @override
  Widget build(BuildContext context) {
    return const CatalogMasterScreen(config: _config);
  }
}
