import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
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
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Model ──────────────────────────────

class UserDto {
  final String id;
  final String username;
  final String email;
  final String status;
  final String? tenantId;
  final List<String> roles;

  const UserDto({
    required this.id,
    required this.username,
    required this.email,
    required this.status,
    this.tenantId,
    required this.roles,
  });

  factory UserDto.fromJson(Map<String, dynamic> json) => UserDto(
      id: (json['userId'] ?? json['id'])?.toString() ?? '',
      username: (json['username'] ?? json['userName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      status: (json['status'] ?? json['statusCode'] ?? 'ACTIVE').toString(),
        tenantId: json['tenantId']?.toString(),
        roles: (json['roles'] as List<dynamic>? ?? [])
            .map((r) => r.toString())
            .toList(),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class UsersListNotifier extends ListNotifier<UserDto> {
  final Dio _dio;

  UsersListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<UserDto>> fetchPage(PageParams params) async {
    // Backend returns a bare JSON array (Flux) and is not server-paginated.
    final query = <String, dynamic>{};
    if (params.search != null && params.search!.isNotEmpty) {
      query['search'] = params.search;
    }
    final resp = await _dio.get('/v1/users', queryParameters: query);
    return PaginatedResponse.fromJson(resp.data, UserDto.fromJson);
  }

  Future<void> toggleStatus(String userId, String currentStatus) async {
    final newStatus = currentStatus.toLowerCase() == 'active'
        ? 'INACTIVE'
        : 'ACTIVE';
    await _dio.patch('/v1/users/$userId/status', data: {'status': newStatus});
    reload();
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete('/v1/users/$userId');
    reload();
  }
}

final usersListNotifierProvider =
    StateNotifierProvider.autoDispose<UsersListNotifier, ListState<UserDto>>(
  (ref) => UsersListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(usersListNotifierProvider);
    final notifier = ref.read(usersListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Usuarios',
      searchHint: 'Buscar usuario…',
      onSearch: notifier.setSearch,
      floatingActionButton: CreateFab(
        onPressed: () => context.push('/iam/users/new'),
        label: 'Nuevo usuario',
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<UserDto> state,
    UsersListNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los usuarios',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Sin usuarios',
        message: 'No hay usuarios que coincidan con la búsqueda.',
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
            final user = state.items[i];
            return _UserTile(user: user, notifier: notifier);
          },
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserDto user;
  final UsersListNotifier notifier;
  const _UserTile({required this.user, required this.notifier});

  bool get _isActive => user.status.toLowerCase() == 'active';

  Future<void> _confirmToggle(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_isActive ? 'Desactivar usuario' : 'Activar usuario'),
        content: Text(
          _isActive
              ? '¿Desactivar a "${user.username}"?'
              : '¿Activar a "${user.username}"?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isActive ? Colors.red : AppColors.accent),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(_isActive ? 'Desactivar' : 'Activar')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await notifier.toggleStatus(user.id, user.status);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.handle(e).message)),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar a "${user.username}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await notifier.deleteUser(user.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ErrorHandler.handle(e).message)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 16,
              offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: AppColors.accentLight,
          highlightColor: AppColors.accentLight,
          onTap: () => context.push('/iam/users/${user.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                StatusBadge(status: user.status),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppColors.textMuted, size: 20),
                  onSelected: (value) {
                    switch (value) {
                      case 'detail':
                        context.push('/iam/users/${user.id}');
                        break;
                      case 'toggle':
                        _confirmToggle(context);
                        break;
                      case 'delete':
                        _confirmDelete(context);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'detail',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_outline_rounded),
                        title: Text('Ver detalle'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          color: _isActive ? Colors.orange : Colors.green,
                        ),
                        title: Text(_isActive ? 'Desactivar' : 'Activar'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                        title:
                            Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ),
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
