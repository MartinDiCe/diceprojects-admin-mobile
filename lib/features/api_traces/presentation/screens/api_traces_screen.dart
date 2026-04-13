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

final _uuidRegex = RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false);

/// Replaces full UUIDs in a path with a short placeholder so paths are readable.
String _cleanPath(String path) => path.replaceAll(_uuidRegex, '{id}');

/// Formats ISO datetime to readable local format: 13/04/2025 10:30
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

class ApiTraceDto {
  final int apiTraceId;
  final String serviceName;
  final String sourceService;
  final String requestOrigin;
  final String httpMethod;
  final int httpResponseCode;
  final int? durationMs;
  final String? requestTimestamp;
  final String? createdDate;

  const ApiTraceDto({
    required this.apiTraceId,
    required this.serviceName,
    required this.sourceService,
    required this.requestOrigin,
    required this.httpMethod,
    required this.httpResponseCode,
    this.durationMs,
    this.requestTimestamp,
    this.createdDate,
  });

  factory ApiTraceDto.fromJson(Map<String, dynamic> json) => ApiTraceDto(
        apiTraceId: (json['apiTraceId'] as num? ?? 0).toInt(),
        serviceName: json['serviceName']?.toString() ?? '',
        sourceService: json['sourceService']?.toString() ?? '',
        requestOrigin: json['requestOrigin']?.toString() ?? '',
        httpMethod: json['httpMethod']?.toString() ?? '',
        httpResponseCode: (json['httpResponseCode'] as num? ?? 0).toInt(),
        durationMs: json['executionTimeSeconds'] is num
            ? (((json['executionTimeSeconds'] as num).toDouble()) * 1000).round()
            : null,
        requestTimestamp: json['requestTimestamp']?.toString(),
        createdDate: json['createdDate']?.toString(),
      );

  Color get statusColor {
    if (httpResponseCode >= 500) return const Color(0xFFC62828);
    if (httpResponseCode >= 400) return const Color(0xFFE65100);
    if (httpResponseCode >= 300) return const Color(0xFFF9A825);
    return const Color(0xFF2E7D32);
  }

  Color get methodColor {
    switch (httpMethod.toUpperCase()) {
      case 'GET':
        return const Color(0xFF1565C0);
      case 'POST':
        return const Color(0xFF2E7D32);
      case 'PUT':
      case 'PATCH':
        return const Color(0xFFE65100);
      case 'DELETE':
        return const Color(0xFFC62828);
      default:
        return AppColors.textSecondary;
    }
  }
}

class ApiTracesNotifier extends ListNotifier<ApiTraceDto> {
  final Dio _dio;
  ApiTracesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<ApiTraceDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/apitraces',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, ApiTraceDto.fromJson);
  }
}

final apiTracesNotifierProvider =
    StateNotifierProvider.autoDispose<ApiTracesNotifier, ListState<ApiTraceDto>>(
  (ref) => ApiTracesNotifier(ref.watch(dioProvider)),
);

class ApiTracesScreen extends ConsumerWidget {
  const ApiTracesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(apiTracesNotifierProvider);
    final notifier = ref.read(apiTracesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'API Traces',
      searchHint: 'Buscar por path, usuario…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(ListState<ApiTraceDto> state, ApiTracesNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las trazas',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.api_rounded,
        title: 'Sin trazas',
        message: 'No hay registros de API en este momento.',
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
          final trace = state.items[i];
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
                          color: trace.methodColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          trace.httpMethod,
                          style: TextStyle(
                            color: trace.methodColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: trace.statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${trace.httpResponseCode}',
                          style: TextStyle(
                            color: trace.statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (trace.durationMs != null) ...[
                        const SizedBox(width: 8),
                        Text('${trace.durationMs}ms',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _cleanPath(
                      trace.requestOrigin.isNotEmpty
                          ? trace.requestOrigin
                          : '${trace.serviceName}${trace.sourceService.isNotEmpty ? ' ← ${trace.sourceService}' : ''}',
                    ),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (trace.serviceName.isNotEmpty)
                        Text(
                          trace.serviceName,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const Spacer(),
                      if (trace.createdDate != null)
                        Text(_fmtDate(trace.createdDate),
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
