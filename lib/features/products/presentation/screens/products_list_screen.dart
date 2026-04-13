import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProductDto {
  final String id;
  final String name;
  final String? sku;
  final String? category;
  final double? price;
  final String status;
  final String? imageUrl;

  const ProductDto({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    this.price,
    required this.status,
    this.imageUrl,
  });

  factory ProductDto.fromJson(Map<String, dynamic> json) => ProductDto(
        // API returns 'productId' as primary key
        id: (json['productId'] ?? json['id'])?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
        sku: json['sku']?.toString(),
        category: json['category']?.toString(),
        // API returns 'basePrice' as BigDecimal — may arrive as num or String
        price: _parseDouble(json['basePrice'] ?? json['price']),
        // API returns 'statusCode', fallback to 'status'
        status: (json['statusCode'] ?? json['status'] ?? 'ACTIVE').toString(),
        imageUrl: json['imageUrl']?.toString(),
      );

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }
}

class ProductsListNotifier extends ListNotifier<ProductDto> {
  final Dio _dio;
  ProductsListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<ProductDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/products',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, ProductDto.fromJson);
  }

  Future<void> toggleActive(String id) async {
    await _dio.patch('/v1/products/$id/active');
    reload();
  }

  Future<void> delete(String id) async {
    await _dio.delete('/v1/products/$id');
    reload();
  }
}

final productsListNotifierProvider =
    StateNotifierProvider.autoDispose<ProductsListNotifier, ListState<ProductDto>>(
  (ref) => ProductsListNotifier(ref.watch(dioProvider)),
);

class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsListNotifierProvider);
    final notifier = ref.read(productsListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Productos',
      searchHint: 'Buscar producto…',
      onSearch: notifier.setSearch,
      floatingActionButton: CreateFab(
        onPressed: () async {
          await context.push('/products/new');
          notifier.reload();
        },
        label: 'Nuevo producto',
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
      BuildContext context,
      ListState<ProductDto> state,
      ProductsListNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los productos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Sin productos',
        message: 'No hay productos que coincidan con la búsqueda.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            if (i == state.items.length) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LoadingState());
            }
            final product = state.items[i];
            return _ProductTile(
              product: product,
              onToggle: () => notifier.toggleActive(product.id),
              onDelete: () => notifier.delete(product.id),
            );
          },
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductDto product;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ProductTile({
    required this.product,
    required this.onToggle,
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
            '¿Estás seguro que querés eliminar "${product.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete();
  }

  Future<void> _confirmToggle(BuildContext context) async {
    final isActive = product.status == 'ACTIVE';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isActive ? 'Desactivar producto' : 'Activar producto'),
        content: Text(isActive
            ? '¿Desactivar "${product.name}"?'
            : '¿Activar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirmed == true) onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.accentLight,
          highlightColor: AppColors.accentLight,
          onTap: () => context.push('/products/${product.id}/edit'),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Image / placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (product.sku != null) product.sku!,
                          if (product.price != null)
                            '\$${product.price!.toStringAsFixed(2)}',
                        ].join(' · '),
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: product.status),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 16),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'toggle') _confirmToggle(context);
                    if (v == 'delete') _confirmDelete(context);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(product.status == 'ACTIVE'
                          ? 'Desactivar'
                          : 'Activar'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Eliminar',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.inventory_2_rounded,
            color: AppColors.accent, size: 22),
      );
}
