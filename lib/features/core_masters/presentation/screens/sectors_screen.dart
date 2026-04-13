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
        sectorId: json['sectorId']?.toString() ?? json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
      );
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
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
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
        icon: Icons.grid_view_rounded,
        title: 'Sin sectores',
        message: 'No hay sectores registrados.',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoadingMore) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final s = state.items[i];
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final cardBg = isDark ? AppColors.surface : Colors.white;
          final textMuted = isDark ? AppColors.sidebarTextMuted : AppColors.textSecondary;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.08)
                    : AppColors.border.withValues(alpha: 0.50),
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor:
                    isDark ? AppColors.accentDark : AppColors.accentLight,
                child: Text(
                  s.code.isNotEmpty ? s.code[0] : 'S',
                  style: TextStyle(
                    color: isDark ? AppColors.white : AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(s.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.code,
                      style: TextStyle(fontSize: 12, color: textMuted)),
                  if (s.description != null)
                    Text(s.description!,
                        style: TextStyle(fontSize: 12, color: textMuted)),
                  const SizedBox(height: 4),
                  StatusBadge(status: s.active ? 'ACTIVE' : 'INACTIVE'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
