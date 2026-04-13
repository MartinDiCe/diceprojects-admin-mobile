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

class NotifTypeDto {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String status;

  const NotifTypeDto({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.status,
  });

  factory NotifTypeDto.fromJson(Map<String, dynamic> json) => NotifTypeDto(
      id: (json['notifTypeId'] ??
          json['notificationTypeId'] ??
          json['typeId'] ??
          json['id'])
        ?.toString() ??
        '',
      code: (json['code'] ?? json['typeCode'] ?? json['notifTypeCode'] ?? '')
        .toString(),
      name: (json['name'] ?? json['typeName'] ?? json['notifTypeName'] ?? '')
        .toString(),
      description:
        (json['description'] ?? json['typeDescription'])?.toString(),
      // Backend sends active (boolean), not status string
      status: json['active'] == true
          ? 'ACTIVE'
          : (json['active'] == false
              ? 'INACTIVE'
              : (json['status'] ?? json['statusCode'] ?? 'ACTIVE').toString()),
      );
}

class NotifTypesNotifier extends ListNotifier<NotifTypeDto> {
  final Dio _dio;
  NotifTypesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<NotifTypeDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/notification-types',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, NotifTypeDto.fromJson);
  }
}

final notifTypesNotifierProvider =
    StateNotifierProvider.autoDispose<NotifTypesNotifier, ListState<NotifTypeDto>>(
  (ref) => NotifTypesNotifier(ref.watch(dioProvider)),
);

class NotifTypesScreen extends ConsumerWidget {
  const NotifTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notifTypesNotifierProvider);
    final notifier = ref.read(notifTypesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Tipos de Notificación',
      searchHint: 'Buscar tipo…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<NotifTypeDto> state, NotifTypesNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los tipos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Sin tipos',
        message: 'No hay tipos de notificación configurados.',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.notifications_rounded,
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
                              t.code,
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
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
      ),
    );
  }
}
