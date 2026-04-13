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

class NotifVariableDto {
  final String id;
  final String name;
  final String? description;
  final String? type;
  final String? defaultValue;

  const NotifVariableDto({
    required this.id,
    required this.name,
    this.description,
    this.type,
    this.defaultValue,
  });

  factory NotifVariableDto.fromJson(Map<String, dynamic> json) =>
      NotifVariableDto(
        // Backend key: variableId
        id: (json['variableId'] ?? json['id'])?.toString() ?? '',
        // Backend key: variableName
        name: (json['variableName'] ?? json['name'] ?? '').toString(),
        description: json['description']?.toString(),
        // Backend key: category (TENANT, USER, AUTH, etc.)
        type: (json['category'] ?? json['type'])?.toString(),
        // Backend key: exampleValue
        defaultValue: (json['exampleValue'] ?? json['defaultValue'])?.toString(),
      );
}

class NotifVariablesNotifier extends ListNotifier<NotifVariableDto> {
  final Dio _dio;
  NotifVariablesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<NotifVariableDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/notification-template-variables',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, NotifVariableDto.fromJson);
  }
}

final notifVariablesNotifierProvider =
    StateNotifierProvider.autoDispose<NotifVariablesNotifier, ListState<NotifVariableDto>>(
  (ref) => NotifVariablesNotifier(ref.watch(dioProvider)),
);

class NotifVariablesScreen extends ConsumerWidget {
  const NotifVariablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notifVariablesNotifierProvider);
    final notifier = ref.read(notifVariablesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Variables',
      searchHint: 'Buscar variable…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<NotifVariableDto> state, NotifVariablesNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las variables',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.code_rounded,
        title: 'Sin variables',
        message: 'No hay variables de notificación configuradas.',
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
          final v = state.items[i];
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
                      child: const Icon(Icons.code_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '{{${v.name}}}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (v.description != null)
                            Text(
                              v.description!,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          if (v.defaultValue != null)
                            Text(
                              'Default: ${v.defaultValue}',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (v.type != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(v.type!,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500)),
                      ),
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
