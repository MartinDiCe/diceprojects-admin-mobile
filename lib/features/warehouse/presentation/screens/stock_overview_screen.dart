import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/warehouse/presentation/screens/warehouses_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Model ──────────────────────────────

class StockItemDto {
  final String productPresentationId;
  final String sku;
  final String productName;
  final String warehouseId;
  final num availableQty;
  final num reservedQty;

  const StockItemDto({
    required this.productPresentationId,
    required this.sku,
    required this.productName,
    required this.warehouseId,
    required this.availableQty,
    required this.reservedQty,
  });

  factory StockItemDto.fromJson(Map<String, dynamic> json) => StockItemDto(
        productPresentationId:
            json['productPresentationId']?.toString() ?? '',
        sku: json['sku']?.toString() ?? '',
        productName: json['productName']?.toString() ?? '',
        warehouseId: json['warehouseId']?.toString() ?? '',
        availableQty: (json['availableQty'] as num?) ?? 0,
        reservedQty: (json['reservedQty'] as num?) ?? 0,
      );
}

// ────────────────────────────── Warehouses lookup ──────────────────────────────

final _warehousesLookupProvider = StateNotifierProvider.autoDispose<
    _WarehousesLookupNotifier, AsyncValue<List<WarehouseDto>>>(
  (ref) => _WarehousesLookupNotifier(ref.watch(dioProvider)),
);

class _WarehousesLookupNotifier
    extends StateNotifier<AsyncValue<List<WarehouseDto>>> {
  final Dio _dio;

  _WarehousesLookupNotifier(this._dio) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await _dio.get(
        '/v1/warehouses',
        queryParameters: const {
          'page': 0,
          'size': 100,
          'pageSize': 100,
        },
      );
      final page = PaginatedResponse.fromJson(resp.data, WarehouseDto.fromJson);
      state = AsyncValue.data(page.items);
    } catch (e, st) {
      state = AsyncValue.error(ErrorHandler.handle(e).message, st);
    }
  }
}

final _selectedWarehouseIdProvider =
    StateProvider.autoDispose<String?>((ref) => null);

// ────────────────────────────── Stock Notifier ──────────────────────────────

class StockListNotifier extends ListNotifier<StockItemDto> {
  final Dio _dio;
  String? _warehouseId;

  StockListNotifier(this._dio) : super();

  String? get warehouseId => _warehouseId;

  void setWarehouseId(String? warehouseId) {
    if (_warehouseId == warehouseId) return;
    _warehouseId = warehouseId;
    reload();
  }

  @override
  Future<PaginatedResponse<StockItemDto>> fetchPage(PageParams params) async {
    if (_warehouseId == null || _warehouseId!.isEmpty) {
      return const PaginatedResponse(
        items: [],
        totalElements: 0,
        totalPages: 0,
        currentPage: 0,
        hasMore: false,
      );
    }

    final query = params.toQueryParams();
    query['warehouseId'] = _warehouseId;

    final resp = await _dio.get(
      '/v1/stock',
      queryParameters: query,
    );

    return PaginatedResponse.fromJson(resp.data, StockItemDto.fromJson);
  }
}

final stockListNotifierProvider =
    StateNotifierProvider.autoDispose<StockListNotifier, ListState<StockItemDto>>(
  (ref) => StockListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class StockOverviewScreen extends ConsumerWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(_warehousesLookupProvider);
    final selectedWarehouseId = ref.watch(_selectedWarehouseIdProvider);

    final stockState = ref.watch(stockListNotifierProvider);
    final stockNotifier = ref.read(stockListNotifierProvider.notifier);

    warehousesAsync.whenData((warehouses) {
      if (warehouses.isNotEmpty && (selectedWarehouseId == null)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ref.read(_selectedWarehouseIdProvider.notifier).state =
              warehouses.first.warehouseId;
          stockNotifier.setWarehouseId(warehouses.first.warehouseId);
        });
      }
    });

    if (selectedWarehouseId != null && stockNotifier.warehouseId != selectedWarehouseId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        stockNotifier.setWarehouseId(selectedWarehouseId);
      });
    }

    return AppPageScaffold(
      title: 'Stock',
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: warehousesAsync.when(
              loading: () => const SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Cargando depósitos…'),
                ),
              ),
              error: (err, _) => Row(
                children: [
                  Expanded(
                    child: Text(
                      err.toString(),
                      style: TextStyle(color: Colors.red.shade700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              data: (warehouses) {
                if (warehouses.isEmpty) {
                  return const SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('No hay depósitos disponibles.'),
                    ),
                  );
                }

                return DropdownButtonFormField<String>(
                  key: ValueKey(selectedWarehouseId ?? 'none'),
                  initialValue: selectedWarehouseId,
                  decoration: InputDecoration(
                    labelText: 'Depósito',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: warehouses
                      .map(
                        (w) => DropdownMenuItem(
                          value: w.warehouseId,
                          child: Text(
                            w.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    ref.read(_selectedWarehouseIdProvider.notifier).state = v;
                    stockNotifier.setWarehouseId(v);
                  },
                );
              },
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _StockList(state: stockState, notifier: stockNotifier),
          ),
        ],
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  final ListState<StockItemDto> state;
  final StockListNotifier notifier;

  const _StockList({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar el stock',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Sin stock',
        message: 'No hay stock para el depósito seleccionado.',
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

            final item = state.items[i];
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
                          Icons.inventory_2_rounded,
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
                              item.productName,
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
                              item.sku,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Disp. ${item.availableQty}',
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Res. ${item.reservedQty}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
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
