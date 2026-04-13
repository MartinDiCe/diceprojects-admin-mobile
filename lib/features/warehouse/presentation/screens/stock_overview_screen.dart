import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Models ──────────────────────────────

class _StockWarehouseOption {
  final String warehouseId;
  final String name;
  const _StockWarehouseOption({required this.warehouseId, required this.name});
}

class StockItemDto {
  final String? productPresentationId;
  final String? sku;
  final String? productName;
  final String? warehouseId;
  final num availableQty;
  final num reservedQty;

  const StockItemDto({
    this.productPresentationId,
    this.sku,
    this.productName,
    this.warehouseId,
    required this.availableQty,
    required this.reservedQty,
  });

  factory StockItemDto.fromJson(Map<String, dynamic> json) => StockItemDto(
        productPresentationId: json['productPresentationId']?.toString(),
        sku: json['sku']?.toString(),
        productName: json['productName']?.toString(),
        warehouseId: json['warehouseId']?.toString(),
        availableQty: (json['availableQty'] as num?) ?? 0,
        reservedQty: (json['reservedQty'] as num?) ?? 0,
      );
}

// ────────────────────────────── State ──────────────────────────────

class _StockOverviewState {
  final bool loadingWarehouses;
  final bool loadingStock;
  final List<_StockWarehouseOption> warehouses;
  final String? selectedWarehouseId;
  final List<StockItemDto> stockItems;
  final String? error;

  const _StockOverviewState({
    this.loadingWarehouses = true,
    this.loadingStock = false,
    this.warehouses = const [],
    this.selectedWarehouseId,
    this.stockItems = const [],
    this.error,
  });

  _StockOverviewState copyWith({
    bool? loadingWarehouses,
    bool? loadingStock,
    List<_StockWarehouseOption>? warehouses,
    String? selectedWarehouseId,
    List<StockItemDto>? stockItems,
    String? error,
    bool clearError = false,
  }) =>
      _StockOverviewState(
        loadingWarehouses: loadingWarehouses ?? this.loadingWarehouses,
        loadingStock: loadingStock ?? this.loadingStock,
        warehouses: warehouses ?? this.warehouses,
        selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
        stockItems: stockItems ?? this.stockItems,
        error: clearError ? null : (error ?? this.error),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class _StockOverviewNotifier extends StateNotifier<_StockOverviewState> {
  final Dio _dio;

  _StockOverviewNotifier(this._dio) : super(const _StockOverviewState()) {
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final resp = await _dio.get('/v1/warehouses', queryParameters: {'size': 50});
      final raw = resp.data;
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['content'] != null) {
        list = raw['content'] as List;
      } else {
        list = [];
      }
      final options = list
          .map((e) => _StockWarehouseOption(
                warehouseId: e['warehouseId']?.toString() ?? e['id']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
              ))
          .toList();
      state = state.copyWith(loadingWarehouses: false, warehouses: options);
      if (options.isNotEmpty) {
        await selectWarehouse(options.first.warehouseId);
      }
    } catch (e) {
      state = state.copyWith(loadingWarehouses: false, error: e.toString());
    }
  }

  Future<void> selectWarehouse(String warehouseId) async {
    state = state.copyWith(
        selectedWarehouseId: warehouseId, loadingStock: true, clearError: true);
    try {
      final resp = await _dio.get('/v1/stock',
          queryParameters: {'warehouseId': warehouseId, 'size': 100});
      final raw = resp.data;
      List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['content'] != null) {
        list = raw['content'] as List;
      } else {
        list = [];
      }
      final items = list
          .map((e) => StockItemDto.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(loadingStock: false, stockItems: items);
    } catch (e) {
      state = state.copyWith(loadingStock: false, error: e.toString());
    }
  }
}

final _stockOverviewProvider =
    StateNotifierProvider.autoDispose<_StockOverviewNotifier, _StockOverviewState>(
  (ref) => _StockOverviewNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_stockOverviewProvider);
    final notifier = ref.read(_stockOverviewProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.sidebarTextMuted : AppColors.textSecondary;

    return AppPageScaffold(
      title: 'Stock',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selector de depósito
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: state.loadingWarehouses
                ? const LinearProgressIndicator()
                : state.warehouses.isEmpty
                    ? const Text('Sin depósitos disponibles')
                    : DropdownButtonFormField<String>(
                        initialValue: state.selectedWarehouseId,
                        decoration: InputDecoration(
                          labelText: 'Depósito',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: state.warehouses
                            .map((w) => DropdownMenuItem(
                                value: w.warehouseId, child: Text(w.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) notifier.selectWarehouse(v);
                        },
                      ),
          ),
          const SizedBox(height: 8),

          // Lista de stock
          Expanded(
            child: state.loadingStock
                ? const LoadingState()
                : state.error != null && state.stockItems.isEmpty
                    ? ErrorState(
                        title: 'Error al cargar stock',
                        message: state.error!,
                        onRetry: () {
                          if (state.selectedWarehouseId != null) {
                            notifier.selectWarehouse(state.selectedWarehouseId!);
                          }
                        },
                      )
                    : state.stockItems.isEmpty
                        ? const EmptyState(
                            icon: Icons.inventory_2_outlined,
                            title: 'Sin stock',
                            message: 'Este depósito no tiene stock registrado.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            itemCount: state.stockItems.length,
                            itemBuilder: (ctx, i) {
                              final item = state.stockItems[i];
                              final cardBg = isDark ? AppColors.surface : Colors.white;
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
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: isDark
                                        ? AppColors.accentDark
                                        : AppColors.accentLight,
                                    child: Icon(Icons.inventory_2_rounded,
                                        color: isDark
                                            ? AppColors.white
                                            : AppColors.accent,
                                        size: 18),
                                  ),
                                  title: Text(
                                    item.productName ?? item.sku ?? 'Producto',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (item.sku != null)
                                        Text('SKU: ${item.sku}',
                                            style: TextStyle(
                                                fontSize: 12, color: textMuted)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        _QtyChip(
                                            label: 'Disponible',
                                            qty: item.availableQty,
                                            color: Colors.green.shade700),
                                        const SizedBox(width: 8),
                                        _QtyChip(
                                            label: 'Reservado',
                                            qty: item.reservedQty,
                                            color: Colors.orange.shade700),
                                      ]),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _QtyChip extends StatelessWidget {
  final String label;
  final num qty;
  final Color color;
  const _QtyChip({required this.label, required this.qty, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label: $qty',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
