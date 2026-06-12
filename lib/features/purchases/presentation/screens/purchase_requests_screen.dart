import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _purchaseRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/v1/purchase-requests');
  final data = response.data;
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }
  if (data is Map && data['content'] is List) {
    return (data['content'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
});

class PurchaseRequestsScreen extends ConsumerWidget {
  const PurchaseRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(_purchaseRequestsProvider);

    return AppPageScaffold(
      title: 'Solicitudes de presupuesto',
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(_purchaseRequestsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: requests.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: 'No se pudieron cargar las solicitudes.',
          onRetry: () => ref.invalidate(_purchaseRequestsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.request_quote_rounded,
              title: 'Sin solicitudes',
              message: 'Todavía no hay solicitudes de presupuesto a proveedores.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              final id = item['id']?.toString() ?? '';
              final number = item['number']?.toString() ?? 'Sin numero';
              final title = item['title']?.toString();
              final status = item['status']?.toString() ?? 'DRAFT';
              final currency = item['currency']?.toString() ?? 'ARS';
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  leading: const Icon(Icons.assignment_turned_in_rounded),
                  title: Text(title?.isNotEmpty == true ? title! : number),
                  subtitle: Text('$number · $currency'),
                  trailing: StatusBadge(status: status),
                  onTap: id.isEmpty
                      ? null
                      : () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => _PurchaseRequestDetailDialog(requestId: id),
                          );
                          ref.invalidate(_purchaseRequestsProvider);
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PurchaseRequestDetailDialog extends ConsumerWidget {
  final String requestId;

  const _PurchaseRequestDetailDialog({required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(_purchaseRequestDetailProvider(requestId));
    final perms = ref.watch(permissionsProvider);
    final canSend = perms.hasAnyPermission(['Purchases.Requests.Send', 'Purchases.Admin']);
    final canQuote = perms.hasAnyPermission(['Purchases.SupplierQuotes.Create', 'Purchases.Admin']);
    final canAward = perms.hasAnyPermission(['Purchases.Requests.Award', 'Purchases.Admin']);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: detail.when(
          loading: () => const SizedBox(height: 360, child: LoadingState()),
          error: (_, __) => ErrorState(
            message: 'No se pudo cargar el detalle.',
            onRetry: () => ref.invalidate(_purchaseRequestDetailProvider(requestId)),
          ),
          data: (data) {
            final request = Map<String, dynamic>.from(data['request'] as Map? ?? const {});
            final items = _list(data['items']);
            final suppliers = _list(data['suppliers']);
            final quotes = _list(data['supplierQuotes']);
            final awards = _list(data['awards']);
            final title = request['title']?.toString();
            final number = request['number']?.toString() ?? requestId;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title?.isNotEmpty == true ? title! : number,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(number, style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      StatusBadge(status: request['status']?.toString() ?? 'DRAFT'),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Section(
                        title: 'Items solicitados',
                        children: items.map((e) => _KeyLine(
                              title: e['description']?.toString() ?? 'Item',
                              subtitle: 'Cantidad ${e['quantity'] ?? '-'}',
                            )).toList(),
                      ),
                      _Section(
                        title: 'Proveedores invitados',
                        children: suppliers.map((e) => _KeyLine(
                              title: e['supplier_id']?.toString() ?? e['supplierId']?.toString() ?? 'Proveedor',
                              subtitle: e['status']?.toString() ?? 'PENDING',
                            )).toList(),
                      ),
                      _Section(
                        title: 'Comparacion',
                        children: quotes.map((e) => _KeyLine(
                              title: e['quote_number']?.toString() ?? e['quoteNumber']?.toString() ?? 'Presupuesto',
                              subtitle:
                                  '${e['supplier_id'] ?? e['supplierId'] ?? '-'} · ${e['currency'] ?? 'ARS'} ${e['total'] ?? '-'}',
                              trailing: canAward
                                  ? TextButton.icon(
                                      icon: const Icon(Icons.verified_rounded),
                                      label: const Text('Adjudicar'),
                                      onPressed: () => _award(ref, e),
                                    )
                                  : null,
                            )).toList(),
                      ),
                      if (awards.isNotEmpty)
                        _Section(
                          title: 'Adjudicaciones',
                          children: awards.map((e) => _KeyLine(
                                title: e['supplier_id']?.toString() ?? 'Proveedor',
                                subtitle: '${e['mode'] ?? 'FULL'} · ${e['awarded_total'] ?? '-'}',
                              )).toList(),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canSend)
                        TextButton.icon(
                          icon: const Icon(Icons.outgoing_mail),
                          label: const Text('Enviar'),
                          onPressed: () => _send(ref),
                        ),
                      if (canQuote) ...[
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.price_change_rounded),
                          label: const Text('Cargar presupuesto'),
                          onPressed: () => _openQuoteForm(context, ref, items, suppliers),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _send(WidgetRef ref) async {
    await ref.read(dioProvider).post('/v1/purchase-requests/$requestId/send');
    ref.invalidate(_purchaseRequestDetailProvider(requestId));
  }

  Future<void> _award(WidgetRef ref, Map<String, dynamic> quote) async {
    final quoteId = quote['id']?.toString();
    if (quoteId == null || quoteId.isEmpty) return;
    await ref.read(dioProvider).post(
      '/v1/purchase-requests/$requestId/award-by-total',
      data: {'supplierQuoteId': quoteId},
    );
    ref.invalidate(_purchaseRequestDetailProvider(requestId));
  }

  Future<void> _openQuoteForm(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> suppliers,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _SupplierQuoteDialog(
        requestId: requestId,
        items: items,
        suppliers: suppliers,
      ),
    );
    ref.invalidate(_purchaseRequestDetailProvider(requestId));
  }
}

final _purchaseRequestDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, requestId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/v1/purchase-requests/$requestId');
  return Map<String, dynamic>.from(response.data as Map);
});

class _SupplierQuoteDialog extends StatefulWidget {
  final String requestId;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> suppliers;

  const _SupplierQuoteDialog({
    required this.requestId,
    required this.items,
    required this.suppliers,
  });

  @override
  State<_SupplierQuoteDialog> createState() => _SupplierQuoteDialogState();
}

class _SupplierQuoteDialogState extends State<_SupplierQuoteDialog> {
  final _supplierId = TextEditingController();
  final _quoteNumber = TextEditingController();
  final _taxes = TextEditingController(text: '0');
  final _paymentTerms = TextEditingController();
  final _prices = <String, TextEditingController>{};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.suppliers.isNotEmpty) {
      _supplierId.text = widget.suppliers.first['supplier_id']?.toString() ??
          widget.suppliers.first['supplierId']?.toString() ??
          '';
    }
    for (final item in widget.items) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) _prices[id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _supplierId.dispose();
    _quoteNumber.dispose();
    _taxes.dispose();
    _paymentTerms.dispose();
    for (final controller in _prices.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => AlertDialog(
        title: const Text('Cargar presupuesto proveedor'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: _supplierId, decoration: const InputDecoration(labelText: 'Proveedor')),
                TextField(controller: _quoteNumber, decoration: const InputDecoration(labelText: 'Numero')),
                TextField(controller: _taxes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Impuestos')),
                TextField(controller: _paymentTerms, decoration: const InputDecoration(labelText: 'Condicion de pago')),
                const SizedBox(height: 12),
                for (final item in widget.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _prices[item['id']?.toString()],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: item['description']?.toString() ?? 'Item',
                        helperText: 'Cantidad ${item['quantity'] ?? '-'}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : () => _save(context, ref),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    setState(() => _saving = true);
    final quoteItems = widget.items.map((item) {
      final id = item['id']?.toString() ?? '';
      final quantity = double.tryParse(item['quantity']?.toString() ?? '') ?? 0;
      final unitPrice = double.tryParse(_prices[id]?.text.trim() ?? '') ?? 0;
      return {
        'purchaseRequestItemId': id,
        'productId': item['product_id'] ?? item['productId'],
        'presentationId': item['presentation_id'] ?? item['presentationId'],
        'quotedDescription': item['description'],
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': quantity * unitPrice,
        'withoutStock': unitPrice == 0,
      };
    }).toList();
    await ref.read(dioProvider).post(
      '/v1/purchase-requests/${widget.requestId}/supplier-quotes',
      data: {
        'supplierId': _supplierId.text.trim(),
        'quoteNumber': _quoteNumber.text.trim().isEmpty ? null : _quoteNumber.text.trim(),
        'currency': 'ARS',
        'taxes': double.tryParse(_taxes.text.trim()) ?? 0,
        'paymentTerms': _paymentTerms.text.trim().isEmpty ? null : _paymentTerms.text.trim(),
        'items': quoteItems,
      },
    );
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _KeyLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _KeyLine({required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}
