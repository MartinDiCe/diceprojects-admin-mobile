import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Model ──────────────────────────────

class RoleDto {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String status;
  final int permissionCount;

  const RoleDto({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.status,
    required this.permissionCount,
  });

  factory RoleDto.fromJson(Map<String, dynamic> json) {
    final description = (json['description'])?.toString();
    final permissionsRaw = json['permissions'];
    final permissionCount = permissionsRaw is List ? permissionsRaw.length : 0;

    return RoleDto(
      id: (json['id'])?.toString() ?? '',
      code: (json['code'])?.toString() ?? '',
      // Backend: RoleWithPermissionsDTO.description is the role display name.
      name: (json['description'] ?? json['code'] ?? '')?.toString() ?? '',
      description: description,
      status: (json['status'] ?? 'ACTIVE').toString(),
      permissionCount: permissionCount,
    );
  }
}

// ────────────────────────────── Notifier ──────────────────────────────

class RolesListNotifier extends ListNotifier<RoleDto> {
  final Dio _dio;

  RolesListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<RoleDto>> fetchPage(PageParams params) async {
    debugPrint('[ROLES] fetchPage - calling GET /v1/roles (returns plain Flux/array, no pagination)');
    // Backend returns Flux<RoleWithPermissionsDTO> → plain JSON array, no pagination params needed
    final resp = await _dio.get('/v1/roles');
    debugPrint('[ROLES] status=${resp.statusCode} dataType=${resp.data?.runtimeType}');
    final raw = resp.data?.toString() ?? '';
    debugPrint('[ROLES] data=${raw.substring(0, raw.length > 300 ? 300 : raw.length)}');
    return PaginatedResponse.fromJson(resp.data, RoleDto.fromJson);
  }
}

final rolesListNotifierProvider =
    StateNotifierProvider.autoDispose<RolesListNotifier, ListState<RoleDto>>(
  (ref) => RolesListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class RolesListScreen extends ConsumerWidget {
  const RolesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rolesListNotifierProvider);
    final notifier = ref.read(rolesListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Roles',
      searchHint: 'Buscar rol…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<RoleDto> state,
    RolesListNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los roles',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.shield_outlined,
        title: 'Sin roles',
        message: 'No hay roles que coincidan con la búsqueda.',
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
            final role = state.items[i];
            return _RoleTile(role: role);
          },
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  final RoleDto role;
  const _RoleTile({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.accentLight,
          onTap: () => context.push('/authorization/${role.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.name,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${role.code} · ${role.permissionCount} permisos',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: role.status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
