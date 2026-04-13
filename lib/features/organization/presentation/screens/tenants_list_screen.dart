import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/confirm_dialog.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Model ──────────────────────────────

class TenantDto {
  final String id;
  final String name;
  final String? domain;
  final String status;
  final String? plan;
  final int? branchCount;

  const TenantDto({
    required this.id,
    required this.name,
    this.domain,
    required this.status,
    this.plan,
    this.branchCount,
  });

  factory TenantDto.fromJson(Map<String, dynamic> json) => TenantDto(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        domain: json['domain']?.toString(),
        status: json['status']?.toString() ?? 'ACTIVE',
        plan: json['plan']?.toString(),
        branchCount: (json['branchCount'] as num?)?.toInt(),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class TenantsListNotifier extends ListNotifier<TenantDto> {
  final Dio _dio;
  TenantsListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<TenantDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/tenants',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, TenantDto.fromJson);
  }

  Future<void> delete(String id, BuildContext ctx) async {
    final confirmed = await ConfirmDialog.show(
      ctx,
      title: 'Eliminar empresa',
      message: '¿Estás seguro de que deseas eliminar esta empresa?',
      isDangerous: true,
    );
    if (!confirmed) return;
    await _dio.delete('/v1/tenants/$id');
    reload();
  }

  Future<void> restore(String id) async {
    await _dio.patch('/v1/tenants/$id/restore');
    reload();
  }
}

final tenantsListNotifierProvider =
    StateNotifierProvider.autoDispose<TenantsListNotifier, ListState<TenantDto>>(
  (ref) => TenantsListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class TenantsListScreen extends ConsumerWidget {
  const TenantsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tenantsListNotifierProvider);
    final notifier = ref.read(tenantsListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Empresas',
      searchHint: 'Buscar empresa…',
      onSearch: notifier.setSearch,
      floatingActionButton: CreateFab(
        onPressed: () => context.push('/admin/tenants/new'),
        label: 'Nueva empresa',
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(BuildContext ctx, ListState<TenantDto> state,
      TenantsListNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las empresas',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.business_outlined,
        title: 'Sin empresas',
        message: 'No hay empresas que coincidan.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
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
          final tenant = state.items[i];
          return _TenantTile(
            tenant: tenant,
            notifier: notifier,
          );
        },
      ),
    );
  }
}

class _TenantTile extends StatelessWidget {
  final TenantDto tenant;
  final TenantsListNotifier notifier;
  const _TenantTile({required this.tenant, required this.notifier});

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
          onTap: () => context.push('/admin/tenants/${tenant.id}/edit'),
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
                  child: const Icon(Icons.business_rounded,
                      color: AppColors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.name,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${tenant.domain ?? 'Sin dominio'}${tenant.branchCount != null ? ' · ${tenant.branchCount} sucursales' : ''}',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: tenant.status),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded,
                  color: AppColors.textMuted, size: 16),
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') context.push('/admin/tenants/${tenant.id}/edit');
                    if (v == 'branches') {
                      context.push('/admin/branches?tenantId=${tenant.id}');
                    }
                    if (v == 'delete') notifier.delete(tenant.id, context);
                    if (v == 'restore') notifier.restore(tenant.id);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(value: 'branches', child: Text('Ver Sucursales')),
                    if (tenant.status == 'INACTIVE')
                      const PopupMenuItem(value: 'restore', child: Text('Restaurar')),
                    if (tenant.status != 'INACTIVE')
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar',
                              style: TextStyle(color: Colors.red))),
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
