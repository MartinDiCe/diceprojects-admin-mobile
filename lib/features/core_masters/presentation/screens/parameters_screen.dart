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
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParameterDto {
  final String id;
  final String key;
  final String value;
  final String? description;
  final String? type;
  final String? status;

  const ParameterDto({
    required this.id,
    required this.key,
    required this.value,
    this.description,
    this.type,
    this.status,
  });

  factory ParameterDto.fromJson(Map<String, dynamic> json) => ParameterDto(
        id: json['id']?.toString() ?? '',
        key: json['key'] ?? json['name'] ?? '',
        value: json['value']?.toString() ?? '',
        description: json['description'],
        type: json['type'],
        status: json['status'],
      );
}

class ParametersNotifier extends ListNotifier<ParameterDto> {
  final Dio _dio;
  ParametersNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<ParameterDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/parameters',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, ParameterDto.fromJson);
  }
}

final parametersNotifierProvider =
    StateNotifierProvider.autoDispose<ParametersNotifier, ListState<ParameterDto>>(
  (ref) => ParametersNotifier(ref.watch(dioProvider)),
);

class ParametersScreen extends ConsumerWidget {
  const ParametersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(parametersNotifierProvider);
    final notifier = ref.read(parametersNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Parámetros',
      searchHint: 'Buscar parámetro…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(BuildContext ctx, ListState<ParameterDto> state,
      ParametersNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los parámetros',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.settings_outlined,
        title: 'Sin parámetros',
        message: 'No hay parámetros configurados.',
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
          final param = state.items[i];
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
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: AppColors.accent, size: 22),
                ),
                title: Text(
                  param.key,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      param.value,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.accent),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (param.description != null)
                      Text(
                        param.description!,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (param.status != null)
                      StatusBadge(status: param.status!),
                    if (param.status != null) const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.textSecondary),
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: param.value)),
                      tooltip: 'Copiar valor',
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
