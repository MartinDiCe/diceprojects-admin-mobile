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
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
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
  final double? discountPercent;
  final String status;
  final String? imageUrl;

  const ProductDto({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    this.price,
    this.discountPercent,
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
        discountPercent:
            _parseDouble(json['discountPercent'] ?? json['discount']),
        // API returns 'statusCode', fallback to 'status'
        status: (json['statusCode'] ?? json['status'] ?? 'ACTIVE').toString(),
        imageUrl: _readImageUrl(json),
      );

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static String? _readImageUrl(Map<String, dynamic> json) {
    for (final key in const [
      'imageUrl',
      'mainImageUrl',
      'primaryImageUrl',
      'thumbnailUrl',
      'image_url',
      'main_image_url',
      'imageUrl0',
    ]) {
      final value = json[key]?.toString();
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    for (final key in const ['images', 'gallery', 'productImages']) {
      final raw = json[key];
      if (raw is List && raw.isNotEmpty) {
        for (final item in raw) {
          if (item is Map) {
            final value = (item['url'] ??
                    item['imageUrl'] ??
                    item['publicUrl'] ??
                    item['image_url'])
                ?.toString();
            if (value != null && value.trim().isNotEmpty) {
              return value.trim();
            }
          } else {
            final value = item.toString();
            if (value.trim().isNotEmpty) return value.trim();
          }
        }
      }
    }
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
    final nextTotal =
        state.totalElements > 0 ? state.totalElements - 1 : state.totalElements;
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
      totalElements: nextTotal,
    );
  }
}

final productsListNotifierProvider = StateNotifierProvider.autoDispose<
    ProductsListNotifier, ListState<ProductDto>>(
  (ref) => ProductsListNotifier(ref.watch(dioProvider)),
);

class ProductsListScreen extends ConsumerWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productsListNotifierProvider);
    final notifier = ref.read(productsListNotifierProvider.notifier);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission([
      'Products.Articles.Create',
      'Producto.CrearProducto',
      'Products.Admin',
    ]);
    final canEdit = perms.hasAnyPermission([
      'Products.Articles.Edit',
      'Producto.EditarProducto',
      'Products.Admin',
    ]);
    final canDelete = perms.hasAnyPermission([
      'Products.Articles.Delete',
      'Producto.EliminarProducto',
      'Products.Admin',
    ]);

    return AppPageScaffold(
      title: 'Productos',
      searchHint: 'Buscar producto…',
      onSearch: notifier.setSearch,
      floatingActionButton: canCreate
          ? CreateFab(
              onPressed: () async {
                await context.push('/products/new');
                notifier.reload();
              },
              label: 'Nuevo producto',
            )
          : null,
      body: _buildBody(context, state, notifier, canEdit, canDelete),
    );
  }

  Widget _buildBody(BuildContext context, ListState<ProductDto> state,
      ProductsListNotifier notifier, bool canEdit, bool canDelete) {
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
              onEdit: () async {
                await ctx.push('/products/${product.id}/edit');
                notifier.reload();
              },
              onPresentations: () async {
                await ctx.push(
                  '/products/${product.id}/presentations?name=${Uri.encodeComponent(product.name)}',
                );
                notifier.reload();
              },
              onToggle: () => notifier.toggleActive(product.id),
              onDelete: () => notifier.delete(product.id),
              canEdit: canEdit,
              canDelete: canDelete,
            );
          },
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final ProductDto product;
  final Future<void> Function() onEdit;
  final Future<void> Function() onPresentations;
  final Future<void> Function() onToggle;
  final Future<void> Function() onDelete;
  final bool canEdit;
  final bool canDelete;

  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onPresentations,
    required this.onToggle,
    required this.onDelete,
    required this.canEdit,
    required this.canDelete,
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
    if (confirmed == true && context.mounted) {
      try {
        await onDelete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Producto eliminado.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('No pudimos eliminar el producto. Probá nuevamente.'),
            ),
          );
        }
      }
    }
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
    if (confirmed == true) await onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product.price != null &&
        product.discountPercent != null &&
        product.discountPercent! > 0;
    final discountRate =
        hasDiscount ? product.discountPercent!.clamp(0, 100).toDouble() : 0.0;
    final finalPrice = hasDiscount
        ? product.price! * (1 - (discountRate / 100))
        : product.price;
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
          onTap: canEdit ? onEdit : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (product.sku != null)
                            Text(
                              product.sku!,
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (finalPrice != null)
                            Text(
                              '\$${finalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppColors.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          if (hasDiscount)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE4E6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '-${product.discountPercent!.toStringAsFixed(product.discountPercent! % 1 == 0 ? 0 : 1)}%',
                                style: const TextStyle(
                                  color: Color(0xFFE11D48),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: product.status),
                const SizedBox(width: 2),
                if (canEdit)
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: onEdit,
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textMuted, size: 16),
                if (canEdit || canDelete)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'presentations') onPresentations();
                      if (v == 'toggle') _confirmToggle(context);
                      if (v == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (_) => [
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'presentations',
                          child: Text('Presentaciones'),
                        ),
                      if (canEdit)
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(product.status == 'ACTIVE'
                              ? 'Desactivar'
                              : 'Activar'),
                        ),
                      if (canDelete)
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
