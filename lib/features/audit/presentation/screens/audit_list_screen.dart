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

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _uuidRx = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false);

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} $h:$mi';
  } catch (_) {
    return raw.length > 16 ? raw.substring(0, 16) : raw;
  }
}

/// Truncate UUID to a short readable suffix like #…f3a2 or return as-is.
String _fmtEntityId(String? id) {
  if (id == null) return '';
  if (_uuidRx.hasMatch(id)) return '#…${id.substring(id.length - 6)}';
  return '#$id';
}

class AuditLogDto {
  final String id;
  final String action;
  final String entity;
  final String? entityId;
  final String? username;
  final String? ip;
  final String? createdAt;
  final String? details;

  const AuditLogDto({
    required this.id,
    required this.action,
    required this.entity,
    this.entityId,
    this.username,
    this.ip,
    this.createdAt,
    this.details,
  });

  factory AuditLogDto.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'] as Map<String, dynamic>? ?? {};
    return AuditLogDto(
      id: json['id']?.toString() ?? '',
      // Backend uses eventType (e.g. USER_LOGIN, ROLE_ASSIGNED)
      action: (json['eventType'] ?? json['action'] ?? '').toString(),
      // entity comes from metadata or fallback
      entity: (meta['entity'] ?? json['entity'] ?? meta['resourceType'] ?? '').toString(),
      entityId: (meta['entityId'] ?? meta['resourceId'] ?? json['entityId'])?.toString(),
      // Prefer human-readable username; userId is fallback
      username: (json['username'] ?? json['userId'])?.toString(),
      ip: (meta['ip'] ?? json['ip'])?.toString(),
      createdAt: json['createdAt']?.toString(),
      // Serialise full metadata map as readable detail string
      details: meta.isNotEmpty ? meta.toString() : json['details']?.toString(),
    );
  }

  Color get actionColor {
    switch (action.toUpperCase()) {
      case 'CREATE':
        return const Color(0xFF2E7D32);
      case 'UPDATE':
        return const Color(0xFF1565C0);
      case 'DELETE':
        return const Color(0xFFC62828);
      default:
        return AppColors.textSecondary;
    }
  }
}

class AuditListNotifier extends ListNotifier<AuditLogDto> {
  final Dio _dio;
  AuditListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<AuditLogDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/audit-events',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, AuditLogDto.fromJson);
  }
}

final auditListNotifierProvider =
    StateNotifierProvider.autoDispose<AuditListNotifier, ListState<AuditLogDto>>(
  (ref) => AuditListNotifier(ref.watch(dioProvider)),
);

class AuditListScreen extends ConsumerWidget {
  const AuditListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(auditListNotifierProvider);
    final notifier = ref.read(auditListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Auditoría',
      searchHint: 'Buscar por acción, entidad…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<AuditLogDto> state, AuditListNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los registros',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'Sin registros',
        message: 'No hay registros de auditoría disponibles.',
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
                  child: LoadingState());
            }
            final log = state.items[i];
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
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: log.actionColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log.action,
                            style: TextStyle(
                              color: log.actionColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            [
                              log.entity,
                              if (log.entityId != null) _fmtEntityId(log.entityId),
                            ].join(' '),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            [
                              if (log.username != null) log.username!,
                              if (log.ip != null) log.ip!,
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (log.createdAt != null)
                          Text(
                            _fmtDate(log.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
