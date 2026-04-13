import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Model ──────────────────────────────

class PermissionDto {
  final String id;
  final String code;
  final String module;
  final String? description;

  const PermissionDto({
    required this.id,
    required this.code,
    required this.module,
    this.description,
  });

  factory PermissionDto.fromJson(Map<String, dynamic> json) => PermissionDto(
        id: (json['id'] ?? json['permissionId'] ?? '').toString(),
        code: (json['code'] ?? json['permissionCode'] ?? '').toString(),
        module: (json['module'] ?? json['moduleCode'] ?? '').toString(),
        description: json['description']?.toString(),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class PermissionsListNotifier extends ListNotifier<PermissionDto> {
  final Dio _dio;
  PermissionsListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<PermissionDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/permissions',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, PermissionDto.fromJson);
  }
}

final permissionsListNotifierProvider =
    StateNotifierProvider.autoDispose<PermissionsListNotifier, ListState<PermissionDto>>(
  (ref) => PermissionsListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class PermissionsListScreen extends ConsumerWidget {
  const PermissionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(permissionsListNotifierProvider);
    final notifier = ref.read(permissionsListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Permisos',
      searchHint: 'Buscar permiso o módulo…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<PermissionDto> state, PermissionsListNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los permisos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        title: 'Sin permisos',
        message: 'No hay permisos disponibles.',
      );
    }

    // Group by module
    final grouped = <String, List<PermissionDto>>{};
    for (final p in state.items) {
      grouped.putIfAbsent(p.module, () => []).add(p);
    }
    final modules = grouped.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: modules.length + (state.isLoadingMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == modules.length) {
              return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: LoadingState());
            }
            final module = modules[i];
            final perms = grouped[module]!;
            return _ModuleGroup(module: module, permissions: perms);
          },
        ),
      ),
    );
  }
}

// ────────────────────────────── Module Group ──────────────────────────────

class _ModuleGroup extends StatelessWidget {
  final String module;
  final List<PermissionDto> permissions;
  const _ModuleGroup({required this.module, required this.permissions});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    module.isNotEmpty ? module : 'Sin módulo',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.accent),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${permissions.length}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          // Permission rows
          ...permissions.asMap().entries.map((entry) {
            final idx = entry.key;
            final perm = entry.value;
            final isLast = idx == permissions.length - 1;
            return _PermissionRow(perm: perm, isLast: isLast);
          }),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final PermissionDto perm;
  final bool isLast;
  const _PermissionRow({required this.perm, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        perm.code,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            fontFamily: 'monospace'),
                      ),
                    ),
                    if (perm.description != null &&
                        perm.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        perm.description!,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
