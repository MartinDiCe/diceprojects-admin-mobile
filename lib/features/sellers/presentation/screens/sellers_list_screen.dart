import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Model ──────────────────────────────

class SellerDto {
  final String sellerId;
  final String? tenantId;
  final String sellerCode;
  final String name;
  final String? description;
  final String? email;
  final String? phone;
  final String? logoUrl;
  final String? websiteUrl;
  final bool active;

  const SellerDto({
    required this.sellerId,
    required this.tenantId,
    required this.sellerCode,
    required this.name,
    this.description,
    this.email,
    this.phone,
    this.logoUrl,
    this.websiteUrl,
    required this.active,
  });

  factory SellerDto.fromJson(Map<String, dynamic> json) => SellerDto(
        sellerId: (json['sellerId'] ?? json['id'])?.toString() ?? '',
        tenantId: (json['tenantId'] ?? json['companyId'])?.toString(),
        sellerCode: json['sellerCode']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        logoUrl: json['logoUrl']?.toString(),
        websiteUrl: json['websiteUrl']?.toString(),
        active: json['active'] == true,
      );

  String get statusCode => active ? 'ACTIVE' : 'INACTIVE';
}

// ────────────────────────────── Notifier ──────────────────────────────

enum ActiveFilter { all, active, inactive }

class SellersListNotifier extends ListNotifier<SellerDto> {
  final Dio _dio;
  ActiveFilter _filter = ActiveFilter.all;

  SellersListNotifier(this._dio) : super();

  ActiveFilter get filter => _filter;

  @override
  Future<PaginatedResponse<SellerDto>> fetchPage(PageParams params) async {
    final query = params.toQueryParams();

    if (_filter == ActiveFilter.active) {
      query['active'] = true;
    } else if (_filter == ActiveFilter.inactive) {
      query['active'] = false;
    }

    final resp = await _dio.get(
      '/v1/sellers',
      queryParameters: query,
    );
    return PaginatedResponse.fromJson(resp.data, SellerDto.fromJson);
  }

  void setActiveFilter(ActiveFilter filter) {
    _filter = filter;
    reload();
  }

  Future<void> activate(String sellerId) async {
    await _dio.patch('/v1/sellers/$sellerId/activate');
    reload();
  }

  Future<void> deactivate(String sellerId) async {
    await _dio.patch('/v1/sellers/$sellerId/deactivate');
    reload();
  }
}

final sellersListNotifierProvider =
    StateNotifierProvider.autoDispose<SellersListNotifier, ListState<SellerDto>>(
  (ref) => SellersListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class SellersListScreen extends ConsumerWidget {
  const SellersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellersListNotifierProvider);
    final notifier = ref.read(sellersListNotifierProvider.notifier);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission([
      'Organization.Sellers.Create',
      'Organization.Admin',
    ]);
    final canEdit = perms.hasAnyPermission([
      'Organization.Sellers.Edit',
      'Organization.Admin',
    ]);

    return AppPageScaffold(
      title: 'Vendedores',
      searchHint: 'Buscar vendedor…',
      onSearch: notifier.setSearch,
      actions: [
        PopupMenuButton<ActiveFilter>(
          tooltip: 'Filtrar',
          icon: Icon(Icons.filter_list_rounded, color: AppColors.ink),
          onSelected: notifier.setActiveFilter,
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: ActiveFilter.all,
              checked: notifier.filter == ActiveFilter.all,
              child: const Text('Todos'),
            ),
            CheckedPopupMenuItem(
              value: ActiveFilter.active,
              checked: notifier.filter == ActiveFilter.active,
              child: const Text('Activos'),
            ),
            CheckedPopupMenuItem(
              value: ActiveFilter.inactive,
              checked: notifier.filter == ActiveFilter.inactive,
              child: const Text('Inactivos'),
            ),
          ],
        ),
      ],
      floatingActionButton: canCreate
          ? CreateFab(
              onPressed: () => context.push('/organization/sellers/new'),
              label: 'Nuevo vendedor',
            )
          : null,
      body: _buildBody(context, state, notifier, canEdit),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<SellerDto> state,
    SellersListNotifier notifier,
    bool canEdit,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los vendedores',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Sin vendedores',
        message: 'No hay vendedores que coincidan con la búsqueda.',
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
                child: LoadingState(),
              );
            }
            final seller = state.items[i];
            return _SellerTile(
              seller: seller,
              onEdit: () => ctx.push(
                '/organization/sellers/${seller.sellerId}/edit',
                extra: seller,
              ),
              onToggleActive: () async {
                if (seller.active) {
                  await notifier.deactivate(seller.sellerId);
                } else {
                  await notifier.activate(seller.sellerId);
                }
              },
              canEdit: canEdit,
            );
          },
        ),
      ),
    );
  }
}

class _SellerTile extends StatelessWidget {
  final SellerDto seller;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final bool canEdit;

  const _SellerTile({
    required this.seller,
    required this.onEdit,
    required this.onToggleActive,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (seller.sellerCode.trim().isNotEmpty) subtitleParts.add(seller.sellerCode);
    if ((seller.email ?? '').trim().isNotEmpty) subtitleParts.add(seller.email!.trim());
    if ((seller.phone ?? '').trim().isNotEmpty) subtitleParts.add(seller.phone!.trim());

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        seller.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitleParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitleParts.join(' · '),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                StatusBadge(status: seller.statusCode),
                const SizedBox(width: 2),
                if (canEdit)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'toggle') onToggleActive();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(seller.active ? 'Desactivar' : 'Activar'),
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
}
