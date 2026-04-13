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

class DestacadoDto {
  final String id;
  final String title;
  final String? description;
  final String status;
  final int? order;
  final String? imageUrl;

  const DestacadoDto({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.order,
    this.imageUrl,
  });

  factory DestacadoDto.fromJson(Map<String, dynamic> json) => DestacadoDto(
        id: json['id']?.toString() ?? '',
      // Backend contract uses /v1/featured-products
      // Fields: id, productId, channel, priority, startsAt, endsAt, active, label
      title: (json['label'] ?? json['title'] ?? json['productId'] ?? '').toString(),
      description: (json['channel'] ?? json['description'])?.toString(),
      status: (json['active'] == true || json['status'] == 'ACTIVE') ? 'ACTIVE' : 'INACTIVE',
      order: (json['priority'] as num?)?.toInt() ?? (json['order'] as num?)?.toInt(),
      imageUrl: json['imageUrl']?.toString(),
      );
}

class DestacadosNotifier extends ListNotifier<DestacadoDto> {
  final Dio _dio;
  DestacadosNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<DestacadoDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/featured-products',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, DestacadoDto.fromJson);
  }
}

final destacadosNotifierProvider =
    StateNotifierProvider.autoDispose<DestacadosNotifier, ListState<DestacadoDto>>(
  (ref) => DestacadosNotifier(ref.watch(dioProvider)),
);

class DestacadosScreen extends ConsumerWidget {
  const DestacadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(destacadosNotifierProvider);
    final notifier = ref.read(destacadosNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Destacados',
      searchHint: 'Buscar destacado…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<DestacadoDto> state, DestacadosNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los destacados',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Sin destacados',
        message: 'No hay destacados configurados.',
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
          final item = state.items[i];
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
                splashColor: AppColors.accentLight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.ink),
                            ),
                            if (item.description != null) ...
                              [
                                const SizedBox(height: 2),
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                          ],
                        ),
                      ),
                      if (item.order != null) ...
                        [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('#${item.order}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent)),
                          ),
                          const SizedBox(width: 6),
                        ],
                      StatusBadge(status: item.status),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
      );
}
