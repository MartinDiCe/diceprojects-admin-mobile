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

class FeatureToggleDto {
  final String id;
  final String key;
  final String? description;
  final bool enabled;

  const FeatureToggleDto({
    required this.id,
    required this.key,
    this.description,
    required this.enabled,
  });

  factory FeatureToggleDto.fromJson(Map<String, dynamic> json) =>
      FeatureToggleDto(
        id: json['id']?.toString() ?? '',
        key: json['key'] ?? json['name'] ?? '',
        description: json['description'],
        enabled: json['enabled'] == true || json['value'] == true,
      );
}

class FeatureTogglesNotifier extends ListNotifier<FeatureToggleDto> {
  final Dio _dio;
  FeatureTogglesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<FeatureToggleDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/feature-toggles',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, FeatureToggleDto.fromJson);
  }

  Future<void> toggle(String id) async {
    await _dio.patch('/v1/feature-toggles/$id/toggle');
    reload();
  }
}

final featureTogglesNotifierProvider =
    StateNotifierProvider.autoDispose<FeatureTogglesNotifier, ListState<FeatureToggleDto>>(
  (ref) => FeatureTogglesNotifier(ref.watch(dioProvider)),
);

class FeatureTogglesScreen extends ConsumerWidget {
  const FeatureTogglesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(featureTogglesNotifierProvider);
    final notifier = ref.read(featureTogglesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Feature Flags',
      searchHint: 'Buscar feature flag…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(ListState<FeatureToggleDto> state,
      FeatureTogglesNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los feature flags',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.toggle_off_rounded,
        title: 'Sin feature flags',
        message: 'No hay feature flags configurados.',
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
          final ft = state.items[i];
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
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ft.enabled
                        ? AppColors.accentLight
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    ft.enabled
                        ? Icons.toggle_on_rounded
                        : Icons.toggle_off_rounded,
                    color: ft.enabled
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                title: Text(ft.key,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: ft.description != null
                    ? Text(ft.description!,
                    style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))
                    : null,
                value: ft.enabled,
                onChanged: (_) => notifier.toggle(ft.id),
              ),
            ),
          );
        },
      ),
    );
  }
}
