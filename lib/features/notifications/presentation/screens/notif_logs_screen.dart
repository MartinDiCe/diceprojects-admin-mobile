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
  final String? senderProfileName;
  final String? renderedBody;
  final String? metadataJson;

  const NotifLogDto({
    required this.id,
    required this.channel,
    required this.recipient,
    required this.status,
    this.subject,
    this.type,
    this.sentAt,
    this.error,
    this.senderProfileName,
    this.renderedBody,
    this.metadataJson,
  });

  factory NotifLogDto.fromJson(Map<String, dynamic> json) => NotifLogDto(
        id: (json['notificationLogId'] ?? json['id'])?.toString() ?? '',
        channel: (json['channelTypeCode'] ?? json['channel'] ?? '').toString(),
        recipient: (json['recipient'] ?? '').toString(),
        status: (json['status'] ?? 'SENT').toString(),
        subject: (json['renderedSubject'] ?? json['subject'])?.toString(),
        type: json['type']?.toString(),
        sentAt: (json['createdDate'] ?? json['sentAt'])?.toString(),
        error: (json['errorMessage'] ?? json['error'])?.toString(),
        senderProfileName: json['senderProfileName']?.toString(),
        renderedBody: json['renderedBody']?.toString(),
        metadataJson: json['metadataJson']?.toString(),
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
  // Default: last 7 days (date-only strings, yyyy-MM-dd)
  String _dateFrom = _isoDate(DateTime.now().subtract(const Duration(days: 7)));
  String _dateTo   = _isoDate(DateTime.now());

  NotifLogsNotifier(this._dio) : super();

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void setDateRange(int days) {
    _dateFrom = _isoDate(DateTime.now().subtract(Duration(days: days)));
    _dateTo   = _isoDate(DateTime.now());
    reload();
  }

  @override
  Future<PaginatedResponse<NotifLogDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/notification-logs',
      queryParameters: {
        ...params.toQueryParams(),
        'dateFrom': _dateFrom,
        'dateTo': _dateTo,
        'size': 50,
      },
    );
    return PaginatedResponse.fromJson(resp.data, NotifLogDto.fromJson);
  }
}

final notifLogsNotifierProvider =
    StateNotifierProvider.autoDispose<NotifLogsNotifier, ListState<NotifLogDto>>(
  (ref) => NotifLogsNotifier(ref.watch(dioProvider)),
);

void _showNotifDetail(BuildContext context, NotifLogDto log) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      log.subject ?? 'Detalle de Notificación',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  StatusBadge(status: log.status),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _detailRow('Canal', log.channel),
                  _detailRow('Destinatario', log.recipient),
                  if (log.senderProfileName != null)
                    _detailRow('Perfil remitente', log.senderProfileName!),
                  if (log.sentAt != null)
                    _detailRow('Fecha', _fmtDate(log.sentAt)),
                  if (log.renderedBody != null && log.renderedBody!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Contenido', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        // Strip basic HTML tags for display
                        log.renderedBody!.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
                        style: TextStyle(fontSize: 13, color: AppColors.ink),
                      ),
                    ),
                  ],
                  if (log.error != null && log.error!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Error', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.red.shade700)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(log.error!, style: TextStyle(fontSize: 12, color: Colors.red.shade800)),
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

Widget _detailRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 130,
        child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ),
      Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: AppColors.ink))),
    ],
  ),
);

class NotifLogsScreen extends ConsumerStatefulWidget {
  const NotifLogsScreen({super.key});

  @override
  ConsumerState<NotifLogsScreen> createState() => _NotifLogsScreenState();
}

class _NotifLogsScreenState extends ConsumerState<NotifLogsScreen> {
  int _rangeIndex = 0;
  static const _rangeLabels = ['7 días', '30 días', '90 días'];
  static const _rangeDays   = [7, 30, 90];

  void _setRange(int idx) {
    setState(() => _rangeIndex = idx);
    ref.read(notifLogsNotifierProvider.notifier).setDateRange(_rangeDays[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(notifLogsNotifierProvider);
    final notifier = ref.read(notifLogsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Logs de Notificaciones',
      searchHint: 'Buscar por destinatario…',
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
          Expanded(child: _buildBody(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ListState<NotifLogDto> state, NotifLogsNotifier notifier) {
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
        message: 'No hay registros de notificaciones para el período seleccionado.',
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
                  onTap: () => _showNotifDetail(context, log),
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
                              if (log.senderProfileName != null)
                                Text(
                                  log.senderProfileName!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              else if (log.subject != null)
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
                        const SizedBox(width: 8),
                        StatusBadge(status: log.status),
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
}

