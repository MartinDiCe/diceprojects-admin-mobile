import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Model ──────────────────────────────

class SectorDto {
  final String sectorId;
  final String code;
  final String name;
  final String? description;
  final bool active;

  const SectorDto({
    required this.sectorId,
    required this.code,
    required this.name,
    this.description,
    required this.active,
  });

  factory SectorDto.fromJson(Map<String, dynamic> json) => SectorDto(
        sectorId: (json['sectorId'] ?? json['id'])?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
      );

  String get statusCode => active ? 'ACTIVE' : 'INACTIVE';
}

// ────────────────────────────── Notifier ──────────────────────────────

class SectorsNotifier extends ListNotifier<SectorDto> {
  final Dio _dio;

  SectorsNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<SectorDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/sectors',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, SectorDto.fromJson);
  }
}

final sectorsNotifierProvider =
    StateNotifierProvider.autoDispose<SectorsNotifier, ListState<SectorDto>>(
  (ref) => SectorsNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class SectorsScreen extends ConsumerWidget {
  const SectorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sectorsNotifierProvider);
    final notifier = ref.read(sectorsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Sectores',
      searchHint: 'Buscar sector…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
    ListState<SectorDto> state,
    SectorsNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los sectores',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.grid_view_outlined,
        title: 'Sin sectores',
        message: 'No hay sectores que coincidan con la búsqueda.',
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
                child: LoadingState(),
              );
            }
            final s = state.items[i];
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
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
                        child: const Icon(
                          Icons.grid_view_rounded,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [s.code, s.description]
                                  .where((v) => (v ?? '').trim().isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: s.statusCode),
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
