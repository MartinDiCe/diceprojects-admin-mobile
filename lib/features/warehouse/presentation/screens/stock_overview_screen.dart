import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
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
      final resp = await _dio.get('/v1/stock/list',
          queryParameters: {'warehouseId': warehouseId});
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

  Future<String?> adjustIn({
    required String warehouseId,
    required String productPresentationId,
    required num quantity,
    String? note,
  }) async {
    try {
      await _dio.post('/v1/stock/adjust-in', data: {
        'warehouseId': warehouseId,
        'productPresentationId': productPresentationId,
        'quantity': quantity,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      // Refresh stock list
      await selectWarehouse(warehouseId);
      return null; // success
    } catch (e) {
      return e.toString();
    }
  }
}

final _stockOverviewProvider =
    StateNotifierProvider.autoDispose<_StockOverviewNotifier, _StockOverviewState>(
  (ref) => _StockOverviewNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class StockOverviewScreen extends ConsumerStatefulWidget {
  const StockOverviewScreen({super.key});

  @override
  ConsumerState<StockOverviewScreen> createState() => _StockOverviewScreenState();
}

class _StockOverviewScreenState extends ConsumerState<StockOverviewScreen> {
  bool _adjusting = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showAdjustInDialog(BuildContext context, String warehouseId) async {
    final dio = ref.read(dioProvider);

    // Local state for the modal
    List<Map<String, dynamic>> products = [];
    List<Map<String, dynamic>> presentations = [];
    String? selectedProductId;
    String? selectedProductName;
    String? selectedPresentationId;
    bool loadingProducts = true;
    bool loadingPresentations = false;
    bool submitting = false;
    String? errorMsg;
    final qtyCtrl  = TextEditingController();
    final noteCtrl = TextEditingController();

    // Fetch products
    Future<void> fetchProducts(void Function(void Function()) setModal) async {
      try {
        final resp = await dio.get('/v1/products', queryParameters: {'size': 100, 'page': 0});
        final raw = resp.data;
        final list = raw is Map ? ((raw['content'] ?? raw['items']) as List? ?? []) : (raw as List? ?? []);
        setModal(() {
          products = list.map((e) => e as Map<String, dynamic>).toList();
          loadingProducts = false;
        });
      } catch (e) {
        setModal(() { loadingProducts = false; errorMsg = e.toString(); });
      }
    }

    Future<void> fetchPresentations(String productId, void Function(void Function()) setModal) async {
      setModal(() { loadingPresentations = true; presentations = []; selectedPresentationId = null; });
      try {
        final resp = await dio.get('/v1/products/$productId/presentations');
        final list = (resp.data as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
        setModal(() { presentations = list; loadingPresentations = false; });
      } catch (e) {
        setModal(() { loadingPresentations = false; errorMsg = e.toString(); });
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          // Trigger initial product load once
          if (loadingProducts && products.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => fetchProducts(setModal));
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text('Ajuste de Entrada',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.ink))),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Seleccioná el producto y su presentación para registrar stock.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),

                  // Product dropdown
                  loadingProducts
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: InputDecoration(
                            labelText: 'Producto',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          hint: const Text('Seleccioná un producto'),
                          items: products.map((p) {
                            final id   = p['productId']?.toString() ?? p['id']?.toString() ?? '';
                            final name = p['name']?.toString() ?? id;
                            return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            selectedProductId   = v;
                            selectedProductName = products.firstWhere(
                              (p) => (p['productId'] ?? p['id'])?.toString() == v, orElse: () => {},
                            )['name']?.toString();
                            fetchPresentations(v, setModal);
                          },
                        ),

                  const SizedBox(height: 12),

                  // Presentation dropdown
                  if (loadingPresentations)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(),
                    ))
                  else if (selectedProductId != null)
                    DropdownButtonFormField<String>(
                      value: selectedPresentationId,
                      decoration: InputDecoration(
                        labelText: 'Presentación',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      hint: Text(presentations.isEmpty ? 'Sin presentaciones' : 'Seleccioná una'),
                      items: presentations.map((p) {
                        final pid  = p['presentationId']?.toString() ?? '';
                        final sku  = p['sku']?.toString() ?? '';
                        final type = p['presentationTypeCode']?.toString() ?? '';
                        final qty  = p['unitQuantity']?.toString() ?? '';
                        final unit = p['baseUnitCode']?.toString() ?? '';
                        final label = [
                          if (sku.isNotEmpty) 'SKU: $sku',
                          if (type.isNotEmpty) type,
                          if (qty.isNotEmpty) '$qty $unit',
                        ].join(' · ');
                        return DropdownMenuItem(value: pid,
                          child: Text(label.isNotEmpty ? label : pid, overflow: TextOverflow.ellipsis));
                      }).toList(),
                      onChanged: (v) => setModal(() => selectedPresentationId = v),
                    ),

                  const SizedBox(height: 12),

                  // Quantity
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nota (opcional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: submitting ? null : () async {
                      final pid = selectedPresentationId;
                      final qty = num.tryParse(qtyCtrl.text.trim());
                      if (pid == null || pid.isEmpty) {
                        setModal(() => errorMsg = 'Seleccioná una presentación.');
                        return;
                      }
                      if (qty == null || qty <= 0) {
                        setModal(() => errorMsg = 'Ingresá una cantidad válida.');
                        return;
                      }
                      setModal(() { submitting = true; errorMsg = null; });
                      final err = await ref.read(_stockOverviewProvider.notifier).adjustIn(
                        warehouseId: warehouseId,
                        productPresentationId: pid,
                        quantity: qty,
                        note: noteCtrl.text.trim(),
                      );
                      if (!ctx.mounted) return;
                      if (err == null) {
                        Navigator.pop(ctx);
                      } else {
                        setModal(() { submitting = false; errorMsg = err; });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: submitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Confirmar Ingreso', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(_stockOverviewProvider);
    final notifier = ref.read(_stockOverviewProvider.notifier);
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.sidebarTextMuted : AppColors.textSecondary;

    return AppPageScaffold(
      title: 'Stock',
      floatingActionButton: state.selectedWarehouseId != null
          ? CreateFab(
              label: 'Ajuste Entrada',
              icon: Icons.add_rounded,
              onPressed: () => _showAdjustInDialog(context, state.selectedWarehouseId!),
            )
          : null,
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
                            title: 'Sin stock registrado',
                            message:
                                'Los productos aparecen aquí cuando tienen movimientos de entrada. Usá el botón + para registrar el stock inicial.',
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                            itemCount: state.stockItems.length,
                            itemBuilder: (ctx, i) {
                              final item = state.stockItems[i];
                              final cardBg = isDark ? AppColors.surface : Colors.white;
                              // Fallback: show short productPresentationId if no name
                              final pid  = item.productPresentationId;
                              final name = item.productName ??
                                  item.sku ??
                                  (pid != null && pid.length > 8
                                      ? '#…${pid.substring(pid.length - 8)}'
                                      : (pid ?? 'Producto'));
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
                                  title: Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 14)),
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
