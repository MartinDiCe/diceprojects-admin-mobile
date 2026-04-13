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

DateTime? _parseAnyDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    // ISO string: "2026-04-13T10:30:00Z"
    return DateTime.parse(raw).toLocal();
  } catch (_) {}
  try {
    // Epoch seconds as number string: "1713001200.123"
    final epoch = double.parse(raw);
    return DateTime.fromMillisecondsSinceEpoch((epoch * 1000).round(), isUtc: true).toLocal();
  } catch (_) {}
  return null;
}

String _fmtDate(String? raw) {
  final dt = _parseAnyDate(raw);
  if (dt == null) return raw ?? '';
  final d  = dt.day.toString().padLeft(2, '0');
  final mo = dt.month.toString().padLeft(2, '0');
  final h  = dt.hour.toString().padLeft(2, '0');
  final mi = dt.minute.toString().padLeft(2, '0');
  return '$d/$mo/${dt.year} $h:$mi';
}

/// Human-readable label for IAM event types.
String _labelForEvent(String code) {
  switch (code.toUpperCase()) {
    case 'USER_LOGIN':            return 'Inicio de sesión';
    case 'USER_LOGOUT':           return 'Cierre de sesión';
    case 'USER_CREATED':          return 'Usuario creado';
    case 'USER_UPDATED':          return 'Usuario actualizado';
    case 'USER_DELETED':          return 'Usuario eliminado';
    case 'ROLE_ASSIGNED':         return 'Rol asignado';
    case 'ROLE_REVOKED':          return 'Rol revocado';
    case 'PERMISSION_GRANTED':    return 'Permiso otorgado';
    case 'PERMISSION_REVOKED':    return 'Permiso revocado';
    case 'PASSWORD_CHANGED':      return 'Contraseña cambiada';
    case 'PASSWORD_RESET':        return 'Contraseña restablecida';
    case 'INVITATION_SENT':       return 'Invitación enviada';
    case 'INVITATION_ACCEPTED':   return 'Invitación aceptada';
    case 'INVITATION_REJECTED':   return 'Invitación rechazada';
    case 'TOKEN_REFRESH':         return 'Token renovado';
    case 'TOKEN_REVOKED':         return 'Token revocado';
    case 'ACCESS_DENIED':         return 'Acceso denegado';
    case 'TENANT_CREATED':        return 'Empresa creada';
    case 'TENANT_UPDATED':        return 'Empresa actualizada';
    case 'SELLER_CREATED':        return 'Vendedor creado';
    default:
      // "SOME_EVENT_CODE" → "Algún evento code"
      return code
          .replaceAll('_', ' ')
          .toLowerCase()
          .split(' ')
          .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
          .join(' ');
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
  final String action;        // raw eventType code
  final String label;         // human-readable label
  final String entity;
  final String? entityId;
  final String? username;
  final String? ip;
  final String? createdAt;
  final String? details;
  final Map<String, dynamic> metadata;

  const AuditLogDto({
    required this.id,
    required this.action,
    required this.label,
    required this.entity,
    this.entityId,
    this.username,
    this.ip,
    this.createdAt,
    this.details,
    this.metadata = const {},
  });

  factory AuditLogDto.fromJson(Map<String, dynamic> json) {
    final meta   = json['metadata'] as Map<String, dynamic>? ?? {};
    final code   = (json['eventType'] ?? json['action'] ?? '').toString();
    // Try to find a human-readable actor name from metadata or fallback to userId
    final actor  = (meta['username'] ?? meta['email'] ?? meta['userEmail']
                 ?? json['username'] ?? json['userId'])?.toString();
    return AuditLogDto(
      id:       json['id']?.toString() ?? '',
      action:   code,
      label:    _labelForEvent(code),
      entity:   (meta['entity'] ?? json['entity'] ?? meta['resourceType'] ?? '').toString(),
      entityId: (meta['entityId'] ?? meta['resourceId'] ?? json['entityId'])?.toString(),
      username: actor,
      ip:       (meta['ip'] ?? json['ip'])?.toString(),
      createdAt: json['createdAt']?.toString(),
      details:  meta.isNotEmpty ? null : json['details']?.toString(),
      metadata: meta,
    );
  }

  Color get actionColor {
    final c = action.toUpperCase();
    if (c.contains('LOGIN') || c.contains('ACCEPTED')) return const Color(0xFF2E7D32);
    if (c.contains('LOGOUT') || c.contains('DENIED') || c.contains('REVOK')) return const Color(0xFFC62828);
    if (c.contains('DELETE') || c.contains('REJECTED')) return const Color(0xFFC62828);
    if (c.contains('CREAT') || c.contains('GRANT') || c.contains('ASSIGN')) return const Color(0xFF1565C0);
    if (c.contains('UPDATE') || c.contains('CHANGED') || c.contains('RESET')) return const Color(0xFFE65100);
    if (c.contains('INVIT') || c.contains('SENT')) return const Color(0xFF6A1B9A);
    return AppColors.textSecondary;
  }
}

class AuditListNotifier extends ListNotifier<AuditLogDto> {
  final Dio _dio;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to   = DateTime.now().add(const Duration(hours: 1));

  AuditListNotifier(this._dio) : super();

  void setDateRange(DateTime from, DateTime to) {
    _from = from;
    _to   = to;
    reload();
  }

  @override
  Future<PaginatedResponse<AuditLogDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/audit-events',
      queryParameters: {
        ...params.toQueryParams(),
        'from': _from.toUtc().toIso8601String(),
        'to':   _to.toUtc().toIso8601String(),
        'size': 50,
      },
    );
    return PaginatedResponse.fromJson(resp.data, AuditLogDto.fromJson);
  }
}

final auditListNotifierProvider =
    StateNotifierProvider.autoDispose<AuditListNotifier, ListState<AuditLogDto>>(
  (ref) => AuditListNotifier(ref.watch(dioProvider)),
);

class AuditListScreen extends ConsumerStatefulWidget {
  const AuditListScreen({super.key});

  @override
  ConsumerState<AuditListScreen> createState() => _AuditListScreenState();
}

class _AuditListScreenState extends ConsumerState<AuditListScreen> {
  int _rangeIndex = 0;
  static const _rangeLabels = ['7 días', '30 días', '90 días'];
  static const _rangeDays   = [7, 30, 90];

  void _setRange(int idx) {
    setState(() => _rangeIndex = idx);
    final days = _rangeDays[idx];
    ref.read(auditListNotifierProvider.notifier).setDateRange(
      DateTime.now().subtract(Duration(days: days)),
      DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(auditListNotifierProvider);
    final notifier = ref.read(auditListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Auditoría',
      searchHint: 'Buscar por acción, entidad…',
      onSearch: notifier.setSearch,
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(children: List.generate(_rangeLabels.length, (i) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_rangeLabels[i]),
                selected: _rangeIndex == i,
                onSelected: (_) => _setRange(i),
                selectedColor: AppColors.accent,
                labelStyle: TextStyle(
                  color: _rangeIndex == i ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: _rangeIndex == i ? AppColors.accent : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ))),
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(ListState<AuditLogDto> state, AuditListNotifier notifier) {
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
        message: 'No hay registros de auditoría para el período seleccionado.',
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
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showAuditDetail(context, log),
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
                                color: log.actionColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                log.label,
                                style: TextStyle(
                                  color: log.actionColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 16, color: Colors.black26),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                log.username != null ? log.username! : 'Sistema',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
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
                                softWrap: false,
                              ),
                          ],
                        ),
                        if (log.ip != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'IP: ${log.ip}',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAuditDetail(BuildContext context, AuditLogDto log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.90,
        builder: (_, ctrl) => Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: log.actionColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(log.label, style: TextStyle(color: log.actionColor, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ]),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    _auditRow('Evento', log.action),
                    if (log.username != null) _auditRow('Usuario / Actor', log.username!),
                    if (log.ip != null) _auditRow('IP', log.ip!),
                    if (log.createdAt != null) _auditRow('Fecha', _fmtDate(log.createdAt)),
                    if (log.entity.isNotEmpty) _auditRow('Entidad', log.entity),
                    if (log.entityId != null) _auditRow('ID Entidad', log.entityId!),
                    if (log.metadata.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Metadata', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: log.metadata.entries
                              .where((e) => e.value != null)
                              .map((e) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(width: 120, child: Text(e.key, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
                                        Expanded(child: Text(e.value.toString(), style: TextStyle(fontSize: 12, color: AppColors.ink))),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _auditRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.ink))),
      ],
    ),
  );
}
