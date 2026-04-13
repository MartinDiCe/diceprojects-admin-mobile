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

class NotifTemplateDto {
  final String id;
  final String name;
  final String? channel;
  final String? subject;
  final String status;
  final String? notifType;

  const NotifTemplateDto({
    required this.id,
    required this.name,
    this.channel,
    this.subject,
    required this.status,
    this.notifType,
  });

  factory NotifTemplateDto.fromJson(Map<String, dynamic> json) =>
      NotifTemplateDto(
        id: json['id']?.toString() ?? '',
        name: (json['name'] ?? '').toString(),
        // Backend does not have 'channel' at template level
        channel: json['channel']?.toString(),
        subject: json['subject']?.toString(),
        // Backend sends active (boolean), not status string
        status: json['active'] == true
            ? 'ACTIVE'
            : (json['active'] == false
                ? 'INACTIVE'
                : (json['status'] ?? 'ACTIVE').toString()),
        // Backend key: notificationTypeId
        notifType: (json['notificationTypeId'] ?? json['notifType'])?.toString(),
      );
}

class NotifTemplatesNotifier extends ListNotifier<NotifTemplateDto> {
  final Dio _dio;
  NotifTemplatesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<NotifTemplateDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/notification-templates',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, NotifTemplateDto.fromJson);
  }
}

final notifTemplatesNotifierProvider =
    StateNotifierProvider.autoDispose<NotifTemplatesNotifier, ListState<NotifTemplateDto>>(
  (ref) => NotifTemplatesNotifier(ref.watch(dioProvider)),
);

class NotifTemplatesScreen extends ConsumerWidget {
  const NotifTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notifTemplatesNotifierProvider);
    final notifier = ref.read(notifTemplatesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Templates de Notificación',
      searchHint: 'Buscar template…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<NotifTemplateDto> state, NotifTemplatesNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los templates',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.description_outlined,
        title: 'Sin templates',
        message: 'No hay templates de notificación configurados.',
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
          final t = state.items[i];
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
                      child: const Icon(Icons.description_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (t.channel != null) t.channel!,
                              if (t.notifType != null) t.notifType!,
                            ].join(' · '),
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: t.status),
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
