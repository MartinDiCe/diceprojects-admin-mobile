import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/widgets/tenant_scope_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedWarehouseOpsTenantProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final selectedWarehouseOpsSellerProvider =
    StateProvider.autoDispose<String?>((ref) => null);
final selectedWarehouseOpsTabProvider =
    StateProvider.autoDispose<WarehouseOpsTab>(
        (ref) => WarehouseOpsTab.reservations);

enum WarehouseOpsTab { reservations, reorder, transfers }

class WarehouseSelectOption {
  final String id;
  final String label;

  const WarehouseSelectOption(this.id, this.label);
}

class WarehouseOperationRow {
  final String id;
  final String title;
  final String subtitle;
  final String status;
  final String trailing;

  const WarehouseOperationRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.trailing,
  });
}

class WarehouseOperationsNotifier
    extends StateNotifier<AsyncValue<List<WarehouseOperationRow>>> {
  final Dio _dio;
  final String? tenantId;
  final String? sellerId;
  final WarehouseOpsTab tab;

  WarehouseOperationsNotifier(this._dio, this.tenantId, this.sellerId, this.tab)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final path = switch (tab) {
        WarehouseOpsTab.reservations => '/v1/warehouse/reservations',
        WarehouseOpsTab.reorder => '/v1/warehouse/reorder-rules',
        WarehouseOpsTab.transfers => '/v1/warehouse/transfer-orders',
      };
      final response = await _dio.get(path,
          options: tenantScopeOptions(tenantId, sellerId: sellerId));
      final data = response.data;
      final list = data is List
          ? data.cast<dynamic>()
          : (data is Map && data['content'] is List
              ? (data['content'] as List)
              : <dynamic>[]);
      state = AsyncValue.data(list
          .whereType<Map>()
          .map((raw) => _mapRow(raw.cast<String, dynamic>()))
          .toList());
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> reservationAction(String id, String action) async {
    await _dio.patch('/v1/warehouse/reservations/$id/$action',
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    await load();
  }

  Future<void> transferStatus(String id, String status) async {
    await _dio.patch('/v1/warehouse/transfer-orders/$id/status',
        data: {'status': status},
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    await load();
  }

  Future<List<WarehouseSelectOption>> listWarehouses() async {
    final response = await _dio.get('/v1/warehouses',
        queryParameters: {'page': 0, 'pageSize': 100},
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    final list = _extractList(response.data);
    return list
        .whereType<Map>()
        .map((raw) {
          final json = raw.cast<String, dynamic>();
          final id = (json['warehouseId'] ?? json['id'])?.toString() ?? '';
          final name = (json['name'] ?? json['code'] ?? 'Depósito').toString();
          return WarehouseSelectOption(id, name);
        })
        .where((item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<WarehouseSelectOption>> listProductPresentations() async {
    final response = await _dio.get('/v1/products',
        queryParameters: {
          'page': 0,
          'pageSize': 80,
          if (tenantId != null) 'companyId': tenantId,
          if (sellerId != null) 'sellerId': sellerId,
          'statusCode': 'ACTIVE',
        },
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    final products = _extractList(response.data);
    final options = <WarehouseSelectOption>[];
    for (final raw in products.whereType<Map>()) {
      final product = raw.cast<String, dynamic>();
      final productId =
          (product['productId'] ?? product['id'])?.toString() ?? '';
      if (productId.isEmpty) continue;
      final productName =
          (product['name'] ?? product['productName'] ?? 'Artículo').toString();
      final productSku = (product['sku'] ?? '').toString();
      try {
        final presentationsResp = await _dio.get(
            '/v1/products/$productId/presentations',
            options: tenantScopeOptions(tenantId, sellerId: sellerId));
        for (final prRaw
            in _extractList(presentationsResp.data).whereType<Map>()) {
          final pr = prRaw.cast<String, dynamic>();
          final active = pr['active'] != false;
          final allowsStock = pr['allowsStock'] != false;
          final id = (pr['presentationId'] ?? pr['id'])?.toString() ?? '';
          if (!active || !allowsStock || id.isEmpty) continue;
          final sku =
              (pr['sku'] ?? pr['presentationTypeCode'] ?? '').toString();
          final unit = (pr['baseUnitCode'] ?? '').toString();
          options.add(WarehouseSelectOption(id,
              '$productName${productSku.isNotEmpty ? ' · $productSku' : ''} · $sku · $unit'));
        }
      } catch (_) {
        // Si un producto falla al leer presentaciones, seguimos con el resto.
      }
    }
    options.sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  Future<void> createReservation({
    required String warehouseId,
    required String productPresentationId,
    required double quantity,
    required String referenceId,
    String? note,
  }) async {
    await _dio.post('/v1/warehouse/reservations',
        data: {
          'warehouseId': warehouseId,
          'productPresentationId': productPresentationId,
          'referenceType': 'MOBILE',
          'referenceId': referenceId,
          'quantity': quantity,
          'note': note,
        },
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    await load();
  }

  Future<void> createReorderRule({
    required String warehouseId,
    required String productPresentationId,
    required double minQty,
    required double reorderPointQty,
    required double maxQty,
  }) async {
    await _dio.post('/v1/warehouse/reorder-rules',
        data: {
          'warehouseId': warehouseId.isEmpty ? null : warehouseId,
          'productPresentationId': productPresentationId,
          'minQty': minQty,
          'reorderPointQty': reorderPointQty,
          'maxQty': maxQty,
          'active': true,
        },
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    await load();
  }

  Future<void> createTransfer({
    required String sourceWarehouseId,
    required String targetWarehouseId,
    required String productPresentationId,
    required double quantity,
    String? note,
  }) async {
    await _dio.post('/v1/warehouse/transfer-orders',
        data: {
          'sourceWarehouseId': sourceWarehouseId,
          'targetWarehouseId': targetWarehouseId,
          'note': note,
          'items': [
            {
              'productPresentationId': productPresentationId,
              'quantity': quantity
            }
          ],
        },
        options: tenantScopeOptions(tenantId, sellerId: sellerId));
    await load();
  }

  List<dynamic> _extractList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data['content'] is List) return data['content'] as List;
    return const [];
  }

  WarehouseOperationRow _mapRow(Map<String, dynamic> json) {
    if (tab == WarehouseOpsTab.reservations) {
      final id =
          (json['reservationId'] ?? json['reservation_id'])?.toString() ?? '';
      final refType =
          (json['referenceType'] ?? json['reference_type'])?.toString() ??
              'REF';
      final refId =
          (json['referenceId'] ?? json['reference_id'])?.toString() ?? '';
      final presentation =
          (json['productPresentationId'] ?? json['product_presentation_id'])
                  ?.toString() ??
              '';
      final qty = json['quantity']?.toString() ?? '0';
      return WarehouseOperationRow(
        id: id,
        title: '$refType · $refId',
        subtitle: presentation,
        status: (json['statusCode'] ?? json['status_code'])?.toString() ?? '',
        trailing: qty,
      );
    }
    if (tab == WarehouseOpsTab.reorder) {
      final id = (json['ruleId'] ?? json['rule_id'])?.toString() ?? '';
      final presentation =
          (json['productPresentationId'] ?? json['product_presentation_id'])
                  ?.toString() ??
              '';
      final point =
          (json['reorderPointQty'] ?? json['reorder_point_qty'])?.toString() ??
              '0';
      final available =
          (json['availableQty'] ?? json['available_qty'])?.toString() ?? '-';
      final needs =
          json['needsReorder'] == true || json['needs_reorder'] == true;
      return WarehouseOperationRow(
        id: id,
        title: presentation,
        subtitle: 'Disponible $available · punto $point',
        status: needs ? 'REPONER' : 'OK',
        trailing: point,
      );
    }
    final id = (json['transferId'] ?? json['transfer_id'])?.toString() ?? '';
    final source = (json['sourceWarehouseId'] ?? json['source_warehouse_id'])
            ?.toString() ??
        '';
    final target = (json['targetWarehouseId'] ?? json['target_warehouse_id'])
            ?.toString() ??
        '';
    final total =
        (json['totalQuantity'] ?? json['total_quantity'])?.toString() ?? '0';
    return WarehouseOperationRow(
      id: id,
      title: id.length > 8 ? id.substring(0, 8) : id,
      subtitle: '$source → $target',
      status: (json['statusCode'] ?? json['status_code'])?.toString() ?? '',
      trailing: total,
    );
  }
}

String _opsKey(String? tenantId, String? sellerId, WarehouseOpsTab tab) =>
    '${tenantId ?? ''}|${sellerId ?? ''}|${tab.name}';

final warehouseOperationsProvider = StateNotifierProvider.autoDispose.family<
    WarehouseOperationsNotifier,
    AsyncValue<List<WarehouseOperationRow>>,
    String>(
  (ref, key) {
    final parts = key.split('|');
    return WarehouseOperationsNotifier(
      ref.watch(dioProvider),
      parts[0].isEmpty ? null : parts[0],
      parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      WarehouseOpsTab.values.firstWhere((tab) => tab.name == parts[2]),
    );
  },
);

class WarehouseOperationsScreen extends ConsumerWidget {
  const WarehouseOperationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final tenant = ref.watch(selectedWarehouseOpsTenantProvider);
    final seller = ref.watch(selectedWarehouseOpsSellerProvider);
    final tab = ref.watch(selectedWarehouseOpsTabProvider);
    final effectiveTenant = auth.isAdminGlobal ? tenant : auth.tenantId;
    final key = _opsKey(effectiveTenant, seller, tab);
    final state = ref.watch(warehouseOperationsProvider(key));
    final notifier = ref.read(warehouseOperationsProvider(key).notifier);

    return AppPageScaffold(
      title: 'Operaciones almacén',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateOperationSheet(context, ref, notifier, tab),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          TenantScopeFilter(
              selectedTenantProvider: selectedWarehouseOpsTenantProvider),
          SellerScopeFilter(
            selectedSellerProvider: selectedWarehouseOpsSellerProvider,
            tenantId: effectiveTenant,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<WarehouseOpsTab>(
              segments: const [
                ButtonSegment(
                    value: WarehouseOpsTab.reservations,
                    label: Text('Reservas')),
                ButtonSegment(
                    value: WarehouseOpsTab.reorder, label: Text('Reposición')),
                ButtonSegment(
                    value: WarehouseOpsTab.transfers,
                    label: Text('Transferencias')),
              ],
              selected: {tab},
              onSelectionChanged: (value) => ref
                  .read(selectedWarehouseOpsTabProvider.notifier)
                  .state = value.first,
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const LoadingState(),
              error: (error, _) => ErrorState(
                title: 'No pudimos cargar operaciones',
                message: error.toString(),
                onRetry: () =>
                    ref.read(warehouseOperationsProvider(key).notifier).load(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Sin operaciones',
                    message: 'No hay registros para el alcance seleccionado.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(warehouseOperationsProvider(key).notifier)
                      .load(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _OperationTile(
                      row: items[index],
                      tab: tab,
                      onReservationAction: (action) => ref
                          .read(warehouseOperationsProvider(key).notifier)
                          .reservationAction(items[index].id, action),
                      onTransferStatus: (status) => ref
                          .read(warehouseOperationsProvider(key).notifier)
                          .transferStatus(items[index].id, status),
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

Future<void> _openCreateOperationSheet(
  BuildContext context,
  WidgetRef ref,
  WarehouseOperationsNotifier notifier,
  WarehouseOpsTab tab,
) async {
  final warehousesFuture = notifier.listWarehouses();
  final presentationsFuture = notifier.listProductPresentations();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return FutureBuilder<List<List<WarehouseSelectOption>>>(
        future: Future.wait([warehousesFuture, presentationsFuture]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final warehouses = snapshot.data![0];
          final presentations = snapshot.data![1];
          return _CreateOperationForm(
            tab: tab,
            warehouses: warehouses,
            presentations: presentations,
            onSubmit: ({
              required warehouseId,
              required sourceWarehouseId,
              required targetWarehouseId,
              required productPresentationId,
              required quantity,
              required referenceId,
              required minQty,
              required reorderPointQty,
              required maxQty,
              required note,
            }) async {
              if (tab == WarehouseOpsTab.reservations) {
                await notifier.createReservation(
                  warehouseId: warehouseId,
                  productPresentationId: productPresentationId,
                  quantity: quantity,
                  referenceId: referenceId,
                  note: note,
                );
              } else if (tab == WarehouseOpsTab.reorder) {
                await notifier.createReorderRule(
                  warehouseId: warehouseId,
                  productPresentationId: productPresentationId,
                  minQty: minQty,
                  reorderPointQty: reorderPointQty,
                  maxQty: maxQty,
                );
              } else {
                await notifier.createTransfer(
                  sourceWarehouseId: sourceWarehouseId,
                  targetWarehouseId: targetWarehouseId,
                  productPresentationId: productPresentationId,
                  quantity: quantity,
                  note: note,
                );
              }
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
            },
          );
        },
      );
    },
  );
}

class _CreateOperationForm extends StatefulWidget {
  final WarehouseOpsTab tab;
  final List<WarehouseSelectOption> warehouses;
  final List<WarehouseSelectOption> presentations;
  final Future<void> Function({
    required String warehouseId,
    required String sourceWarehouseId,
    required String targetWarehouseId,
    required String productPresentationId,
    required double quantity,
    required String referenceId,
    required double minQty,
    required double reorderPointQty,
    required double maxQty,
    required String note,
  }) onSubmit;

  const _CreateOperationForm({
    required this.tab,
    required this.warehouses,
    required this.presentations,
    required this.onSubmit,
  });

  @override
  State<_CreateOperationForm> createState() => _CreateOperationFormState();
}

class _CreateOperationFormState extends State<_CreateOperationForm> {
  String warehouseId = '';
  String sourceWarehouseId = '';
  String targetWarehouseId = '';
  String productPresentationId = '';
  final quantityCtrl = TextEditingController(text: '1');
  final referenceCtrl = TextEditingController();
  final minCtrl = TextEditingController(text: '0');
  final pointCtrl = TextEditingController(text: '0');
  final maxCtrl = TextEditingController(text: '0');
  final noteCtrl = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    warehouseId =
        widget.warehouses.isNotEmpty ? widget.warehouses.first.id : '';
    sourceWarehouseId =
        widget.warehouses.isNotEmpty ? widget.warehouses.first.id : '';
    targetWarehouseId =
        widget.warehouses.length > 1 ? widget.warehouses[1].id : '';
    productPresentationId =
        widget.presentations.isNotEmpty ? widget.presentations.first.id : '';
    referenceCtrl.text = 'MOB-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    quantityCtrl.dispose();
    referenceCtrl.dispose();
    minCtrl.dispose();
    pointCtrl.dispose();
    maxCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final title = switch (widget.tab) {
      WarehouseOpsTab.reservations => 'Nueva reserva',
      WarehouseOpsTab.reorder => 'Nueva regla de reposición',
      WarehouseOpsTab.transfers => 'Nueva transferencia',
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (widget.presentations.isEmpty)
              const Text(
                  'No hay artículos con presentaciones stockeables para operar.'),
            if (widget.presentations.isNotEmpty) ...[
              if (widget.tab == WarehouseOpsTab.transfers) ...[
                _OptionSelect(
                    label: 'Origen',
                    value: sourceWarehouseId,
                    options: widget.warehouses,
                    onChanged: (value) =>
                        setState(() => sourceWarehouseId = value)),
                _OptionSelect(
                    label: 'Destino',
                    value: targetWarehouseId,
                    options: widget.warehouses,
                    onChanged: (value) =>
                        setState(() => targetWarehouseId = value)),
              ] else
                _OptionSelect(
                    label: 'Depósito',
                    value: warehouseId,
                    options: widget.warehouses,
                    onChanged: (value) => setState(() => warehouseId = value)),
              _OptionSelect(
                  label: 'Artículo / presentación',
                  value: productPresentationId,
                  options: widget.presentations,
                  onChanged: (value) =>
                      setState(() => productPresentationId = value)),
              if (widget.tab == WarehouseOpsTab.reorder) ...[
                _TextInput(
                    label: 'Mínimo',
                    controller: minCtrl,
                    keyboardType: TextInputType.number),
                _TextInput(
                    label: 'Punto reposición',
                    controller: pointCtrl,
                    keyboardType: TextInputType.number),
                _TextInput(
                    label: 'Máximo',
                    controller: maxCtrl,
                    keyboardType: TextInputType.number),
              ] else ...[
                _TextInput(
                    label: 'Cantidad',
                    controller: quantityCtrl,
                    keyboardType: TextInputType.number),
                if (widget.tab == WarehouseOpsTab.reservations)
                  _TextInput(label: 'Referencia', controller: referenceCtrl),
                _TextInput(label: 'Observaciones', controller: noteCtrl),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(saving ? 'Guardando...' : 'Guardar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (productPresentationId.isEmpty) return;
    setState(() => saving = true);
    try {
      await widget.onSubmit(
        warehouseId: warehouseId,
        sourceWarehouseId: sourceWarehouseId,
        targetWarehouseId: targetWarehouseId,
        productPresentationId: productPresentationId,
        quantity: double.tryParse(quantityCtrl.text.replaceAll(',', '.')) ?? 0,
        referenceId: referenceCtrl.text.trim(),
        minQty: double.tryParse(minCtrl.text.replaceAll(',', '.')) ?? 0,
        reorderPointQty:
            double.tryParse(pointCtrl.text.replaceAll(',', '.')) ?? 0,
        maxQty: double.tryParse(maxCtrl.text.replaceAll(',', '.')) ?? 0,
        note: noteCtrl.text.trim(),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _OptionSelect extends StatelessWidget {
  final String label;
  final String value;
  final List<WarehouseSelectOption> options;
  final ValueChanged<String> onChanged;

  const _OptionSelect({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: options.any((item) => item.id == value) ? value : null,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: options
            .map((item) => DropdownMenuItem(
                value: item.id,
                child: Text(item.label, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  const _TextInput(
      {required this.label, required this.controller, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }
}

class _OperationTile extends StatelessWidget {
  final WarehouseOperationRow row;
  final WarehouseOpsTab tab;
  final Future<void> Function(String action) onReservationAction;
  final Future<void> Function(String status) onTransferStatus;

  const _OperationTile({
    required this.row,
    required this.tab,
    required this.onReservationAction,
    required this.onTransferStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x11000000)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.title,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(row.subtitle,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              StatusBadge(status: row.status),
            ],
          ),
          const SizedBox(height: 10),
          Text('Cantidad ${row.trailing}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          if (tab == WarehouseOpsTab.reservations &&
              row.status == 'ACTIVE') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => onReservationAction('release'),
                  child: const Text('Liberar'),
                ),
                FilledButton(
                  onPressed: () => onReservationAction('consume'),
                  child: const Text('Consumir'),
                ),
              ],
            ),
          ],
          if (tab == WarehouseOpsTab.transfers &&
              row.status != 'RECEIVED' &&
              row.status != 'CANCELLED') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                    onPressed: () => onTransferStatus('PREPARED'),
                    child: const Text('Preparar')),
                OutlinedButton(
                    onPressed: () => onTransferStatus('IN_TRANSIT'),
                    child: const Text('Tránsito')),
                FilledButton(
                    onPressed: () => onTransferStatus('RECEIVED'),
                    child: const Text('Recibir')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
