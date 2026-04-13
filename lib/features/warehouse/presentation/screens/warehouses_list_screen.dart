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

class WarehouseDto {
  final String warehouseId;
  final String? companyId;
  final String? sellerId;
  final String name;
  final String code;
  final String? description;
  final String? address;
  final bool active;
  final String? warehouseTypeCode;

  const WarehouseDto({
    required this.warehouseId,
    this.companyId,
    this.sellerId,
    required this.name,
    required this.code,
    this.description,
    this.address,
    required this.active,
    this.warehouseTypeCode,
  });

  factory WarehouseDto.fromJson(Map<String, dynamic> json) => WarehouseDto(
        warehouseId: json['warehouseId']?.toString() ?? json['id']?.toString() ?? '',
        companyId: json['companyId']?.toString(),
        sellerId: json['sellerId']?.toString(),
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        description: json['description']?.toString(),
        address: json['address']?.toString(),
        active: json['active'] == true,
        warehouseTypeCode: json['warehouseTypeCode']?.toString(),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class WarehousesListNotifier extends ListNotifier<WarehouseDto> {
  final Dio _dio;
  WarehousesListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<WarehouseDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/warehouses',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, WarehouseDto.fromJson);
  }
}

final warehousesListNotifierProvider =
    StateNotifierProvider.autoDispose<WarehousesListNotifier, ListState<WarehouseDto>>(
  (ref) => WarehousesListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class WarehousesListScreen extends ConsumerWidget {
  const WarehousesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(warehousesListNotifierProvider);
    final notifier = ref.read(warehousesListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Depósitos',
      searchHint: 'Buscar depósito…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<WarehouseDto> state,
    WarehousesListNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los depósitos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.warehouse_rounded,
        title: 'Sin depósitos',
        message: 'No hay depósitos que coincidan.',
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
          final wh = state.items[i];
          return _WarehouseCard(warehouse: wh);
        },
      ),
    );
  }
}

class _WarehouseCard extends StatelessWidget {
  final WarehouseDto warehouse;
  const _WarehouseCard({required this.warehouse});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isDark ? AppColors.accentDark : AppColors.accentLight,
          child: Icon(
            Icons.warehouse_rounded,
            color: isDark ? AppColors.white : AppColors.accent,
            size: 20,
          ),
        ),
        title: Text(warehouse.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(warehouse.code, style: TextStyle(fontSize: 12, color: textMuted)),
            if (warehouse.warehouseTypeCode != null)
              Text(warehouse.warehouseTypeCode!,
                  style: TextStyle(fontSize: 12, color: textMuted)),
            if (warehouse.address != null)
              Text(warehouse.address!,
                  style: TextStyle(fontSize: 12, color: textMuted)),
            const SizedBox(height: 4),
            StatusBadge(status: warehouse.active ? 'ACTIVE' : 'INACTIVE'),
          ],
        ),
      ),
    );
  }
}
