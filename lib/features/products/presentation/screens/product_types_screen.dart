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

// ────────────────────────────── Model ──────────────────────────────

class ProductTypeDto {
  final String typeId;
  final String code;
  final String name;
  final String? description;
  final bool active;
  final bool isGlobal;

  const ProductTypeDto({
    required this.typeId,
    required this.code,
    required this.name,
    this.description,
    required this.active,
    required this.isGlobal,
  });

  factory ProductTypeDto.fromJson(Map<String, dynamic> json) => ProductTypeDto(
        typeId: (json['typeId'] ?? json['id'])?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
        isGlobal: json['isGlobal'] == true,
      );

  String get statusCode => active ? 'ACTIVE' : 'INACTIVE';
}

// ────────────────────────────── Notifier ──────────────────────────────

class ProductTypesNotifier extends ListNotifier<ProductTypeDto> {
  final Dio _dio;
  final String? tenantId;

  ProductTypesNotifier(this._dio, this.tenantId) : super();

  @override
  Future<PaginatedResponse<ProductTypeDto>> fetchPage(PageParams params) async {
    final query = params.toQueryParams();
    query['size'] = 50;
    query['pageSize'] = 50;

    final resp = await _dio.get(
      '/v1/product-types',
      queryParameters: query,
      options: tenantScopeOptions(tenantId),
    );
    return PaginatedResponse.fromJson(resp.data, ProductTypeDto.fromJson);
  }
}

final selectedProductTypesTenantProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final productTypesNotifierProvider = StateNotifierProvider.autoDispose
    .family<ProductTypesNotifier, ListState<ProductTypeDto>, String?>(
  (ref, tenantId) => ProductTypesNotifier(ref.watch(dioProvider), tenantId),
);

// ────────────────────────────── Screen ──────────────────────────────

class ProductTypesScreen extends ConsumerWidget {
  const ProductTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final selectedTenant = ref.watch(selectedProductTypesTenantProvider);
    final effectiveTenant = auth.isAdminGlobal ? selectedTenant : auth.tenantId;
    final state = ref.watch(productTypesNotifierProvider(effectiveTenant));
    final notifier =
        ref.read(productTypesNotifierProvider(effectiveTenant).notifier);

    return AppPageScaffold(
      title: 'Tipos de Producto',
      searchHint: 'Buscar tipo…',
      onSearch: notifier.setSearch,
      body: Column(
        children: [
          TenantScopeFilter(
            selectedTenantProvider: selectedProductTypesTenantProvider,
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(
    ListState<ProductTypeDto> state,
    ProductTypesNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los tipos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'Sin tipos',
        message: 'No hay tipos que coincidan con la búsqueda.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final t = state.items[i];
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        Icons.category_rounded,
                        color: AppColors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  t.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (t.isGlobal)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Global',
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [t.code, t.description]
                                .where((v) => (v ?? '').trim().isNotEmpty)
                                .join(' · '),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: t.statusCode),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
