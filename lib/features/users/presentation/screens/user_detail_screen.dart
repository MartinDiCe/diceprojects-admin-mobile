import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Model ──────────────────────────────

class UserDetailDto {
  final String id;
  final String username;
  final String email;
  final String status;
  final String? tenantId;
  final String? tenantName;
  final List<String> roles;
  final String? createdAt;
  final String? updatedAt;

  const UserDetailDto({
    required this.id,
    required this.username,
    required this.email,
    required this.status,
    this.tenantId,
    this.tenantName,
    required this.roles,
    this.createdAt,
    this.updatedAt,
  });

  factory UserDetailDto.fromJson(Map<String, dynamic> json) =>
      UserDetailDto(
        id: (json['userId'] ?? json['id'])?.toString() ?? '',
        username: (json['username'] ?? json['userName'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        status: (json['status'] ?? json['statusCode'] ?? 'ACTIVE').toString(),
        tenantId: json['tenantId']?.toString(),
        tenantName: json['tenantName']?.toString(),
        roles: (json['roles'] as List<dynamic>? ?? [])
            .map((r) => r.toString())
            .toList(),
        createdAt: json['createdAt']?.toString(),
        updatedAt: json['updatedAt']?.toString(),
      );
}

// ────────────────────────────── Provider ──────────────────────────────

final userDetailProvider = FutureProvider.autoDispose
    .family<UserDetailDto, String>((ref, userId) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('/v1/users/$userId');
  return UserDetailDto.fromJson(resp.data as Map<String, dynamic>);
});

// ────────────────────────────── Screen ──────────────────────────────

class UserDetailScreen extends ConsumerWidget {
  final String userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userDetailProvider(userId));

    return AppPageScaffold(
      title: 'Detalle de Usuario',
      body: async.when(
        loading: () => const LoadingState(),
        error: (err, _) => ErrorState(
          message: ErrorHandler.handle(err).message,
          onRetry: () => ref.invalidate(userDetailProvider(userId)),
        ),
        data: (user) => _UserDetailBody(user: user),
      ),
    );
  }
}

class _UserDetailBody extends StatelessWidget {
  final UserDetailDto user;
  const _UserDetailBody({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(user: user),
          const SizedBox(height: 16),
          _InfoCard(user: user),
          if (user.roles.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RolesCard(roles: user.roles),
          ],
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final UserDetailDto user;
  const _HeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.accent.withValues(alpha: 0.15),
              child: Text(
                user.username.isNotEmpty
                    ? user.username[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(user.email,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(status: user.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final UserDetailDto user;
  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Información',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Divider(height: 24),
            _InfoRow(label: 'ID', value: user.id),
            if (user.tenantName != null)
              _InfoRow(label: 'Empresa', value: user.tenantName!),
            if (user.createdAt != null)
              _InfoRow(label: 'Creado', value: user.createdAt!),
            if (user.updatedAt != null)
              _InfoRow(label: 'Actualizado', value: user.updatedAt!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _RolesCard extends StatelessWidget {
  final List<String> roles;
  const _RolesCard({required this.roles});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roles',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: roles
                  .map((r) => Chip(
                        label: Text(
                          r,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.1),
                        side: BorderSide.none,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
