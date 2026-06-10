import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool _looksLikeId(String value) {
  final v = value.trim();
  if (v.isEmpty) return false;
  final uuidLike = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  if (uuidLike.hasMatch(v)) return true;
  if (RegExp(r'^\d{3,}$').hasMatch(v)) return true;
  return false;
}

class _RoleLookupDto {
  final String id;
  final String code;
  final String name;

  const _RoleLookupDto({required this.id, required this.code, required this.name});

  factory _RoleLookupDto.fromJson(Map<String, dynamic> json) => _RoleLookupDto(
        id: (json['id'])?.toString() ?? '',
        code: (json['code'])?.toString() ?? '',
        name: (json['description'] ?? json['name'] ?? json['code'] ?? '').toString(),
      );
}

final _rolesLookupProvider = FutureProvider.autoDispose<List<_RoleLookupDto>>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get('/v1/roles');
    return PaginatedResponse.fromJson(resp.data, _RoleLookupDto.fromJson).items;
  },
);

String _resolveRoleLabel(String raw, List<_RoleLookupDto>? lookup) {
  final value = raw.trim();
  if (value.isEmpty) return '';
  String? resolved;
  for (final role in lookup ?? const <_RoleLookupDto>[]) {
    if (role.id == value || role.code == value) {
      resolved = role.name;
      break;
    }
  }
  if (resolved != null && resolved.trim().isNotEmpty) return resolved;
  if (_looksLikeId(value)) return 'Rol';
  return value;
}

String? _resolveRoleId(UserRoleRef role, List<_RoleLookupDto>? lookup) {
  if (role.id != null && role.id!.trim().isNotEmpty) return role.id;
  final code = role.code?.trim();
  if (code == null || code.isEmpty) return null;
  for (final candidate in lookup ?? const <_RoleLookupDto>[]) {
    if (candidate.code == code || candidate.id == code) return candidate.id;
  }
  return null;
}

class UserRoleRef {
  final String? id;
  final String? code;
  final String label;

  const UserRoleRef({this.id, this.code, required this.label});

  factory UserRoleRef.fromJson(dynamic raw) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final id = (map['roleId'] ?? map['id'])?.toString();
      final code = (map['role'] ?? map['code'] ?? map['roleCode'])?.toString();
      final label = (map['description'] ?? map['name'] ?? code ?? id ?? 'Rol')
          .toString();
      return UserRoleRef(id: id, code: code, label: label);
    }
    final text = raw?.toString() ?? '';
    return UserRoleRef(
      id: _looksLikeId(text) ? text : null,
      code: _looksLikeId(text) ? null : text,
      label: text,
    );
  }
}

// ────────────────────────────── Model ──────────────────────────────

class UserDetailDto {
  final String id;
  final String username;
  final String email;
  final String status;
  final String? tenantId;
  final String? tenantName;
  final List<UserRoleRef> roles;
  final String? createdAt;
  final String? updatedAt;
  final String? firstName;
  final String? lastName;

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
    this.firstName,
    this.lastName,
  });

  String get fullName {
    final parts = [firstName, lastName]
        .where((p) => p != null && p!.trim().isNotEmpty)
        .map((p) => p!.trim())
        .toList();
    return parts.join(' ');
  }

  String get displayName {
    final name = fullName;
    if (name.trim().isNotEmpty) return name;
    if (username.trim().isNotEmpty) return username.trim();
    return email.trim().isNotEmpty ? email.trim() : 'Usuario';
  }

  factory UserDetailDto.fromJson(Map<String, dynamic> json) {
    final person = json['person'] is Map
        ? Map<String, dynamic>.from(json['person'] as Map)
        : null;
    return UserDetailDto(
      id: (json['userId'] ?? json['id'])?.toString() ?? '',
      username: (json['username'] ?? json['userName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      status: (json['status'] ?? json['statusCode'] ?? 'ACTIVE').toString(),
      tenantId: json['tenantId']?.toString(),
      tenantName: json['tenantName']?.toString(),
      roles: (json['roles'] as List<dynamic>? ?? [])
          .map(UserRoleRef.fromJson)
          .toList(),
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      firstName: (json['firstName'] ?? json['personFirstName'] ?? person?['firstName'])?.toString(),
      lastName: (json['lastName'] ?? json['personLastName'] ?? person?['lastName'])?.toString(),
    );
  }
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
    final rolesLookupAsync = ref.watch(_rolesLookupProvider);
    final rolesLookup = rolesLookupAsync.maybeWhen(data: (d) => d, orElse: () => null);

    return AppPageScaffold(
      title: 'Detalle de Usuario',
      body: async.when(
        loading: () => const LoadingState(),
        error: (err, _) => ErrorState(
          message: ErrorHandler.handle(err).message,
          onRetry: () => ref.invalidate(userDetailProvider(userId)),
        ),
        data: (user) => _UserDetailBody(user: user, rolesLookup: rolesLookup),
      ),
    );
  }
}

class _UserDetailBody extends StatelessWidget {
  final UserDetailDto user;
  final List<_RoleLookupDto>? rolesLookup;
  const _UserDetailBody({required this.user, required this.rolesLookup});

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
          const SizedBox(height: 16),
          _RolesCard(
            user: user,
            roles: user.roles,
            rolesLookup: rolesLookup,
          ),
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
                user.displayName.isNotEmpty
                    ? user.displayName[0].toUpperCase()
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
                  Text(user.displayName,
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
            if (user.fullName.trim().isNotEmpty)
              _InfoRow(label: 'Nombre completo', value: user.fullName),
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

class _RolesCard extends ConsumerStatefulWidget {
  final UserDetailDto user;
  final List<UserRoleRef> roles;
  final List<_RoleLookupDto>? rolesLookup;
  const _RolesCard({
    required this.user,
    required this.roles,
    required this.rolesLookup,
  });

  @override
  ConsumerState<_RolesCard> createState() => _RolesCardState();
}

class _RolesCardState extends ConsumerState<_RolesCard> {
  String? _selectedRoleId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final canAssign = perms.hasAnyPermission([
      'IAM.Users.Roles.Assign',
      'IAM.Users.Update',
      'IAM.Users.Admin',
    ]);
    final canRemove = perms.hasAnyPermission([
      'IAM.Users.Roles.Remove',
      'IAM.Users.Update',
      'IAM.Users.Admin',
    ]);
    final assignedIds = widget.roles
        .map((role) => _resolveRoleId(role, widget.rolesLookup))
        .whereType<String>()
        .toSet();
    final availableRoles = (widget.rolesLookup ?? const <_RoleLookupDto>[])
        .where((role) => role.id.isNotEmpty && !assignedIds.contains(role.id))
        .toList();

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
            if (widget.roles.isEmpty)
              Text(
                'Este usuario todavía no tiene roles asignados.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.roles
                    .map((r) => Chip(
                          label: Text(
                            _resolveRoleLabel(r.label, widget.rolesLookup),
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: canRemove && !_saving
                              ? () => _removeRole(context, r)
                              : null,
                          backgroundColor:
                              AppColors.accent.withValues(alpha: 0.1),
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
            if (canAssign && availableRoles.isNotEmpty) ...[
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _selectedRoleId,
                decoration: const InputDecoration(labelText: 'Asignar rol'),
                items: availableRoles
                    .map((role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged:
                    _saving ? null : (value) => setState(() => _selectedRoleId = value),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Asignar rol',
                icon: Icons.shield_rounded,
                isLoading: _saving,
                onPressed: _selectedRoleId == null ? null : _assignRole,
                fullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _assignRole() async {
    if (_selectedRoleId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post(
        '/v1/users/assign-role',
        queryParameters: {
          'username': widget.user.username.isNotEmpty
              ? widget.user.username
              : widget.user.email,
          'roleId': _selectedRoleId,
        },
      );
      ref.invalidate(userDetailProvider(widget.user.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.handle(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeRole(BuildContext context, UserRoleRef role) async {
    final roleId = _resolveRoleId(role, widget.rolesLookup);
    if (roleId == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(dioProvider)
          .delete('/v1/users/${widget.user.id}/roles/$roleId');
      ref.invalidate(userDetailProvider(widget.user.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHandler.handle(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
