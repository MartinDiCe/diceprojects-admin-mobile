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

class NotifLogDto {
  final String id;
  final String channel;
  final String recipient;
  final String status;
  final String? subject;
  final String? type;
  final String? sentAt;
  final String? error;

  const NotifLogDto({
    required this.id,
    required this.channel,
    required this.recipient,
    required this.status,
    this.subject,
    this.type,
    this.sentAt,
    this.error,
  });

  factory NotifLogDto.fromJson(Map<String, dynamic> json) => NotifLogDto(
        // Backend key: notificationLogId
        id: (json['notificationLogId'] ?? json['id'])?.toString() ?? '',
        // Backend key: channelTypeCode
        channel: (json['channelTypeCode'] ?? json['channel'] ?? '').toString(),
        recipient: (json['recipient'] ?? '').toString(),
        status: (json['status'] ?? 'SENT').toString(),
        // Backend key: renderedSubject
        subject: (json['renderedSubject'] ?? json['subject'])?.toString(),
        type: json['type']?.toString(),
        // Backend key: createdDate (LocalDateTime → ISO string)
        sentAt: (json['createdDate'] ?? json['sentAt'])?.toString(),
        // Backend key: errorMessage
        error: (json['errorMessage'] ?? json['error'])?.toString(),
      );

  IconData get channelIcon {
    switch (channel.toUpperCase()) {
      case 'EMAIL':
        return Icons.email_rounded;
      case 'SMS':
        return Icons.sms_rounded;
      case 'PUSH':
        return Icons.notifications_rounded;
      default:
        return Icons.send_rounded;
    }
  }
}

class NotifLogsNotifier extends ListNotifier<NotifLogDto> {
  final Dio _dio;
  NotifLogsNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<NotifLogDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/notification-logs',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, NotifLogDto.fromJson);
  }
}

final notifLogsNotifierProvider =
    StateNotifierProvider.autoDispose<NotifLogsNotifier, ListState<NotifLogDto>>(
  (ref) => NotifLogsNotifier(ref.watch(dioProvider)),
);

class NotifLogsScreen extends ConsumerWidget {
  const NotifLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notifLogsNotifierProvider);
    final notifier = ref.read(notifLogsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Logs de Notificaciones',
      searchHint: 'Buscar por destinatario…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(ListState<NotifLogDto> state, NotifLogsNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los logs',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Sin logs',
        message: 'No hay registros de notificaciones.',
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
                      child: Icon(log.channelIcon,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.recipient,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          if (log.subject != null)
                            Text(
                              log.subject!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            '${log.channel}${log.sentAt != null ? ' · ${_fmtDate(log.sentAt)}' : ''}',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: log.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
