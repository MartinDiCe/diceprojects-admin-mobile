import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Models ──────────────────────────────

class RoleDetailDto {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String status;
  final List<PermissionDto> permissions;

  const RoleDetailDto({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.status,
    required this.permissions,
  });

  factory RoleDetailDto.fromJson(Map<String, dynamic> json) {
    final permissionsRaw = json['permissions'];
    final permissionsList = permissionsRaw is List ? permissionsRaw : const <dynamic>[];

    return RoleDetailDto(
      id: (json['id'])?.toString() ?? '',
      code: (json['code'])?.toString() ?? '',
      // Backend: RoleWithPermissionsDTO.description is the role display name.
      name: (json['description'] ?? json['code'] ?? '')?.toString() ?? '',
      description: (json['description'])?.toString(),
      status: (json['status'] ?? 'ACTIVE').toString(),
      permissions: permissionsList
          .map((p) => PermissionDto.fromJson(
                p is Map<String, dynamic>
                    ? p
                    : Map<String, dynamic>.from(p as Map),
              ))
          .toList(),
    );
  }
}

class PermissionDto {
  final String id;
  final String code;
  final String name;
  final String? module;

  const PermissionDto({
    required this.id,
    required this.code,
    required this.name,
    this.module,
  });

  factory PermissionDto.fromJson(Map<String, dynamic> json) => PermissionDto(
        id: (json['id'])?.toString() ?? '',
        code: (json['code'])?.toString() ?? '',
        // Backend: PermissionResponseDTO.description is the permission display name.
        name: (json['description'] ?? json['code'] ?? '')?.toString() ?? '',
        module: (json['module'])?.toString(),
      );
}

// ────────────────────────────── Provider ──────────────────────────────

final roleDetailProvider = FutureProvider.autoDispose
    .family<RoleDetailDto, String>((ref, roleId) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('/v1/roles/$roleId');
  return RoleDetailDto.fromJson(resp.data as Map<String, dynamic>);
});

// ────────────────────────────── Screen ──────────────────────────────

class RoleDetailScreen extends ConsumerWidget {
  final String roleId;
  const RoleDetailScreen({super.key, required this.roleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(roleDetailProvider(roleId));

    return AppPageScaffold(
      title: 'Detalle de Rol',
      body: async.when(
        loading: () => const LoadingState(),
        error: (err, _) => ErrorState(
          message: ErrorHandler.handle(err).message,
          onRetry: () => ref.invalidate(roleDetailProvider(roleId)),
        ),
        data: (role) => _RoleDetailBody(role: role),
      ),
    );
  }
}

class _RoleDetailBody extends StatelessWidget {
  final RoleDetailDto role;
  const _RoleDetailBody({required this.role});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<PermissionDto>>{};
    for (final p in role.permissions) {
      (grouped[p.module ?? 'General'] ??= []).add(p);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoleHeaderCard(role: role),
          const SizedBox(height: 16),
          if (grouped.isNotEmpty)
            ...grouped.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PermissionsGroupCard(
                    module: e.key,
                    permissions: e.value,
                  ),
                )),
          if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Center(
                child: Text(
                  'Este rol no tiene permisos asignados.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoleHeaderCard extends StatelessWidget {
  final RoleDetailDto role;
  const _RoleHeaderCard({required this.role});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF7B2D8B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Color(0xFF7B2D8B), size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(role.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(role.code,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  if (role.description != null) ...[
                    const SizedBox(height: 4),
                    Text(role.description!,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadge(status: role.status),
                      const SizedBox(width: 8),
                      Text(
                        '${role.permissions.length} permisos',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionsGroupCard extends StatelessWidget {
  final String module;
  final List<PermissionDto> permissions;
  const _PermissionsGroupCard(
      {required this.module, required this.permissions});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(module,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Divider(height: 20),
            ...permissions.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.accent, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(p.name,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(p.code,
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
