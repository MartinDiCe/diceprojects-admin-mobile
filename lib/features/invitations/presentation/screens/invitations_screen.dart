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

class InvitationDto {
  final String id;
  final String email;
  final String status;
  final String? role;
  final String? tenantId;
  final String? expiresAt;
  final String? createdAt;

  const InvitationDto({
    required this.id,
    required this.email,
    required this.status,
    this.role,
    this.tenantId,
    this.expiresAt,
    this.createdAt,
  });

  factory InvitationDto.fromJson(Map<String, dynamic> json) =>
      InvitationDto(
        id: json['id']?.toString() ?? '',
        email: json['email'] ?? '',
        status: json['status'] ?? 'PENDING',
        role: (json['role'] ?? json['roleId'])?.toString(),
        tenantId: json['tenantId']?.toString(),
        expiresAt: _maybeDateTimeToString(json['expiresAt']),
        createdAt: _maybeDateTimeToString(json['createdAt']),
      );

  static String? _maybeDateTimeToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;

    // Spring can serialize LocalDateTime as an array:
    // [year, month, day, hour, minute, second, nano]
    if (value is List && value.length >= 6) {
      dynamic at(int i) => (i >= 0 && i < value.length) ? value[i] : null;

      final year = at(0);
      final month = at(1);
      final day = at(2);
      final hour = at(3);
      final minute = at(4);
      final second = at(5);
      final nano = value.length >= 7 ? at(6) : 0;

      if (year is int &&
          month is int &&
          day is int &&
          hour is int &&
          minute is int &&
          second is int) {
        try {
          final microsecond = (nano is int) ? (nano ~/ 1000) : 0;
          final dt = DateTime(year, month, day, hour, minute, second, 0, microsecond);
          return dt.toIso8601String();
        } catch (_) {
          // Fall back to string below.
        }
      }
    }

    return value.toString();
  }
}

class InvitationsNotifier extends ListNotifier<InvitationDto> {
  final Dio _dio;
  InvitationsNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<InvitationDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/invitations',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, InvitationDto.fromJson);
  }
}

final invitationsNotifierProvider = StateNotifierProvider.autoDispose<
    InvitationsNotifier, ListState<InvitationDto>>(
  (ref) => InvitationsNotifier(ref.watch(dioProvider)),
);

// ─── Mapa roleId → nombre legible ────────────────────────────────────────────
// Carga /v1/roles una sola vez y construye {id: description}.
// Si falla, retorna mapa vacío y el tile muestra el código raw.
final _rolesNameMapProvider =
    FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final resp = await dio.get('/v1/roles', queryParameters: {'size': 200});
    final raw = resp.data;
    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = (raw['items'] ?? raw['content'] ?? const <dynamic>[]) as List<dynamic>;
    } else {
      list = const <dynamic>[];
    }
    final map = <String, String>{};
    for (final r in list) {
      final id = (r['id'])?.toString() ?? '';
      final name = (r['description'] ?? r['name'] ?? r['code'] ?? '').toString();
      if (id.isNotEmpty) map[id] = name;
    }
    return map;
  } catch (_) {
    return {};
  }
});

class InvitationsScreen extends ConsumerWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(invitationsNotifierProvider);
    final notifier = ref.read(invitationsNotifierProvider.notifier);
    final rolesAsync = ref.watch(_rolesNameMapProvider);
    final rolesMap = rolesAsync.valueOrNull ?? {};

    return AppPageScaffold(
      title: 'Invitaciones',
      searchHint: 'Buscar por email…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier, rolesMap),
    );
  }

  Widget _buildBody(
      ListState<InvitationDto> state,
      InvitationsNotifier notifier,
      Map<String, String> rolesMap) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las invitaciones',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.mail_outline_rounded,
        title: 'Sin invitaciones',
        message: 'No hay invitaciones pendientes.',
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
          final inv = state.items[i];
          // Resolver nombre del rol: si inv.role es un UUID, buscarlo en el mapa;
          // si ya es un código legible (o si el mapa no lo tiene), mostrarlo tal cual.
          final roleDisplay = inv.role != null
              ? (rolesMap[inv.role!] ?? _formatRoleCode(inv.role!))
              : 'Sin rol asignado';

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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mail_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.email,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            roleDisplay,
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: inv.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Formatea un código de rol legible si no se encuentra en el mapa.
  /// Ej: "PRODUCTS_ADMIN" → "Products Admin"
  String _formatRoleCode(String raw) {
    if (raw.length > 20 && raw.contains('-')) {
      // Es probablemente un UUID → no se pudo resolver
      return 'Sin rol';
    }
    return raw
        .split('_')
        .map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
