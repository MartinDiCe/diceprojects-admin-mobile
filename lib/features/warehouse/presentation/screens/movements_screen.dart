import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Model ──────────────────────────────

class MovementDto {
  final String movementId;
  final String warehouseId;
  final String sku;
  final num quantity;
  final String movementTypeCode;
  final String? note;
  final DateTime? createdAt;

  const MovementDto({
    required this.movementId,
    required this.warehouseId,
    required this.sku,
    required this.quantity,
    required this.movementTypeCode,
    this.note,
    this.createdAt,
  });

  factory MovementDto.fromJson(Map<String, dynamic> json) => MovementDto(
        movementId: json['movementId']?.toString() ?? '',
        warehouseId: json['warehouseId']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        quantity: (json['quantity'] as num?) ?? 0,
        movementTypeCode: json['movementTypeCode']?.toString() ?? '',
        note: json['note']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class MovementsNotifier extends ListNotifier<MovementDto> {
  final Dio _dio;
  final String warehouseId;

  MovementsNotifier(this._dio, this.warehouseId) : super();

  @override
  Future<PaginatedResponse<MovementDto>> fetchPage(PageParams params) async {
    final query = params.toQueryParams();
    query['warehouseId'] = warehouseId;

    final resp = await _dio.get(
      '/v1/stock/movements',
      queryParameters: query,
    );

    return PaginatedResponse.fromJson(resp.data, MovementDto.fromJson);
  }
}

final movementsNotifierProvider = StateNotifierProvider.autoDispose
    .family<MovementsNotifier, ListState<MovementDto>, String>(
  (ref, warehouseId) => MovementsNotifier(ref.watch(dioProvider), warehouseId),
);

// ────────────────────────────── Screen ──────────────────────────────

class MovementsScreen extends ConsumerWidget {
  final String warehouseId;

  const MovementsScreen({
    super.key,
    required this.warehouseId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movementsNotifierProvider(warehouseId));
    final notifier = ref.read(movementsNotifierProvider(warehouseId).notifier);

    return AppPageScaffold(
      title: 'Movimientos',
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
    ListState<MovementDto> state,
    MovementsNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los movimientos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_horiz_outlined,
        title: 'Sin movimientos',
        message: 'No hay movimientos para este depósito.',
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
            final m = state.items[i];
            final subtitleParts = <String>[];
            if (m.note != null && m.note!.trim().isNotEmpty) {
              subtitleParts.add(m.note!.trim());
            }
            if (m.createdAt != null) {
              final dt = m.createdAt!;
              subtitleParts.add(
                '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
              );
            }

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
                          Icons.swap_horiz_rounded,
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
                              m.sku,
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
                              [m.movementTypeCode, ...subtitleParts]
                                  .where((v) => v.trim().isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        m.quantity.toString(),
                        style: TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
