import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/widgets/tenant_scope_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Model ──────────────────────────────

class WarehouseDto {
  final String warehouseId;
  final String? companyId;
  final String? sellerId;
  final String name;
  final String? code;
  final String? description;
  final String? address;
  final bool active;
  final String? warehouseTypeCode;

  const WarehouseDto({
    required this.warehouseId,
    this.companyId,
    this.sellerId,
    required this.name,
    this.code,
    this.description,
    this.address,
    required this.active,
    this.warehouseTypeCode,
  });

  factory WarehouseDto.fromJson(Map<String, dynamic> json) => WarehouseDto(
        warehouseId: (json['warehouseId'] ?? json['id'])?.toString() ?? '',
        companyId: (json['companyId'] ?? json['tenantId'])?.toString(),
        sellerId: json['sellerId']?.toString(),
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString(),
        description: json['description']?.toString(),
        address: json['address']?.toString(),
        active: json['active'] == true,
        warehouseTypeCode: json['warehouseTypeCode']?.toString(),
      );

  String get statusCode => active ? 'ACTIVE' : 'INACTIVE';
}

// ────────────────────────────── Notifier ──────────────────────────────

class WarehousesListNotifier extends ListNotifier<WarehouseDto> {
  final Dio _dio;
  final String? tenantId;
  final String? sellerId;

  WarehousesListNotifier(this._dio, this.tenantId, this.sellerId) : super();

  @override
  Future<PaginatedResponse<WarehouseDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/warehouses',
      queryParameters: params.toQueryParams(),
      options: tenantScopeOptions(tenantId, sellerId: sellerId),
    );
    return PaginatedResponse.fromJson(resp.data, WarehouseDto.fromJson);
  }
}

final selectedWarehousesTenantProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final selectedWarehousesSellerProvider =
    StateProvider.autoDispose<String?>((ref) => null);

String _scopeKey(String? tenantId, String? sellerId) =>
    '${tenantId?.trim() ?? ''}|${sellerId?.trim() ?? ''}';

String? _tenantFromScopeKey(String key) {
  final value = key.split('|').first.trim();
  return value.isEmpty ? null : value;
}

String? _sellerFromScopeKey(String key) {
  final parts = key.split('|');
  if (parts.length < 2) return null;
  final value = parts[1].trim();
  return value.isEmpty ? null : value;
}

final warehousesListNotifierProvider = StateNotifierProvider.autoDispose
    .family<WarehousesListNotifier, ListState<WarehouseDto>, String>(
  (ref, key) => WarehousesListNotifier(
    ref.watch(dioProvider),
    _tenantFromScopeKey(key),
    _sellerFromScopeKey(key),
  ),
);

// ────────────────────────────── Screen ──────────────────────────────

class WarehousesListScreen extends ConsumerWidget {
  const WarehousesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final selectedTenant = ref.watch(selectedWarehousesTenantProvider);
    final selectedSeller = ref.watch(selectedWarehousesSellerProvider);
    final effectiveTenant = auth.isAdminGlobal ? selectedTenant : auth.tenantId;
    final key = _scopeKey(effectiveTenant, selectedSeller);
    final state = ref.watch(warehousesListNotifierProvider(key));
    final notifier = ref.read(warehousesListNotifierProvider(key).notifier);

    return AppPageScaffold(
      title: 'Depósitos',
      searchHint: 'Buscar depósito…',
      onSearch: notifier.setSearch,
      body: Column(
        children: [
          TenantScopeFilter(
              selectedTenantProvider: selectedWarehousesTenantProvider),
          SellerScopeFilter(
            selectedSellerProvider: selectedWarehousesSellerProvider,
            tenantId: effectiveTenant,
          ),
          Expanded(child: _buildBody(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ListState<WarehouseDto> state,
    WarehousesListNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los depósitos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.warehouse_outlined,
        title: 'Sin depósitos',
        message: 'No hay depósitos que coincidan con la búsqueda.',
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
            final w = state.items[i];
            return _WarehouseTile(warehouse: w);
          },
        ),
      ),
    );
  }
}

class _WarehouseTile extends StatelessWidget {
  final WarehouseDto warehouse;

  const _WarehouseTile({required this.warehouse});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if ((warehouse.code ?? '').trim().isNotEmpty) {
      subtitleParts.add(warehouse.code!.trim());
    }
    if ((warehouse.warehouseTypeCode ?? '').trim().isNotEmpty) {
      subtitleParts.add(warehouse.warehouseTypeCode!.trim());
    }
    if ((warehouse.address ?? '').trim().isNotEmpty) {
      subtitleParts.add(warehouse.address!.trim());
    }

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
                  Icons.warehouse_rounded,
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
                      warehouse.name,
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
              StatusBadge(status: warehouse.statusCode),
              const SizedBox(width: 2),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'movements') {
                    context
                        .push('/warehouse/${warehouse.warehouseId}/movements');
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'movements',
                    child: Text('Ver movimientos'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
