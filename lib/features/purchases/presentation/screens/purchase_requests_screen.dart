import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final _purchaseSearchProvider = StateProvider.autoDispose<String>((_) => '');
final _purchaseSourceProvider = StateProvider.autoDispose<String?>((_) => null);

final _purchaseRequestsProvider = FutureProvider.autoDispose<List<_PurchaseRequestDto>>((ref) async {
  final search = ref.watch(_purchaseSearchProvider).trim().toLowerCase();
  final sourceType = ref.watch(_purchaseSourceProvider);
  final response = await ref.watch(dioProvider).get(
    '/v1/purchase-requests',
    queryParameters: {
      if (sourceType != null && sourceType.isNotEmpty) 'sourceType': sourceType,
    },
  );
  final items = _list(response.data).map(_PurchaseRequestDto.fromJson).toList();
  if (search.isEmpty) return items;
  return items
      .where((item) =>
          item.number.toLowerCase().contains(search) ||
          item.title.toLowerCase().contains(search) ||
          item.status.toLowerCase().contains(search))
      .toList();
});

final _purchaseRequestDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, requestId) async {
  final response = await ref.watch(dioProvider).get('/v1/purchase-requests/$requestId');
  return Map<String, dynamic>.from(response.data as Map);
});

final _purchaseSuppliersProvider = FutureProvider.autoDispose<List<_LookupOption>>((ref) async {
  final response = await ref.watch(dioProvider).get(
    '/v1/suppliers',
    queryParameters: const {'page': 0, 'size': 200, 'pageSize': 200, 'status': 'ACTIVE'},
  );
  return PaginatedResponse.fromJson(response.data, _LookupOption.supplier).items;
});

final _purchaseProductsProvider = FutureProvider.autoDispose<List<_ProductOption>>((ref) async {
  final response = await ref.watch(dioProvider).get(
    '/v1/products',
    queryParameters: const {'page': 0, 'size': 300, 'pageSize': 300},
  );
  return PaginatedResponse.fromJson(response.data, _ProductOption.fromJson)
      .items
      .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
      .toList();
});

const _currencyOptions = ['ARS', 'USD', 'EUR', 'BRL'];
const _unitOptions = ['UN', 'KG', 'GR', 'LT', 'ML', 'M', 'CM', 'M2', 'M3', 'CAJA', 'BOLSA', 'ROLLO'];

class PurchaseRequestsScreen extends ConsumerWidget {
  const PurchaseRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(_purchaseRequestsProvider);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission(['Purchases.Requests.Create', 'Purchases.Admin']);

    return AppPageScaffold(
      title: 'Solicitudes de presupuesto',
      searchHint: 'Buscar solicitud...',
      onSearch: (value) => ref.read(_purchaseSearchProvider.notifier).state = value,
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: () => ref.invalidate(_purchaseRequestsProvider),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: canCreate
          ? CreateFab(
              label: 'Nueva solicitud',
              onPressed: () async {
                await _openCreateSheet(context, ref);
                ref.invalidate(_purchaseRequestsProvider);
              },
            )
          : null,
      body: Column(
        children: [
          _SourceFilters(
            selected: ref.watch(_purchaseSourceProvider),
            onChanged: (value) => ref.read(_purchaseSourceProvider.notifier).state = value,
          ),
          Expanded(
            child: requests.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: 'No se pudieron cargar las solicitudes.',
          onRetry: () => ref.invalidate(_purchaseRequestsProvider),
        ),
        data: (items) => _PurchaseRequestsList(items: items),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _PurchaseRequestCreateSheet(),
    );
  }
}

class _SourceFilters extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _SourceFilters({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = <String?, String>{
      null: 'Todas',
      'SALES_QUOTE': 'Cotización ventas',
      'PROJECT_WORK': 'Obra',
      'MANUAL': 'Manual',
    };
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final value = items.keys.elementAt(index);
          return ChoiceChip(
            selected: selected == value,
            label: Text(items[value]!),
            onSelected: (_) => onChanged(value),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: items.length,
      ),
    );
  }
}

class _PurchaseRequestsList extends ConsumerWidget {
  final List<_PurchaseRequestDto> items;

  const _PurchaseRequestsList({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_rounded,
        title: 'Sin solicitudes',
        message: 'Todavia no hay solicitudes de presupuesto a proveedores.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_purchaseRequestsProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await showDialog<void>(
                  context: context,
                  builder: (_) => _PurchaseRequestDetailDialog(requestId: item.id),
                );
                ref.invalidate(_purchaseRequestsProvider);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title.isNotEmpty ? item.title : item.number,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.number} · ${item.documentType} · ${item.currency}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: item.status),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
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
    final suppliers = ref.watch(_purchaseSuppliersProvider).asData?.value ?? const <_LookupOption>[];
    final perms = ref.watch(permissionsProvider);
    final canSend = perms.hasAnyPermission(['Purchases.Requests.Send', 'Purchases.Admin']);
    final canQuote = perms.hasAnyPermission(['Purchases.SupplierQuotes.Create', 'Purchases.Admin']);
    final canAward = perms.hasAnyPermission(['Purchases.Requests.Award', 'Purchases.Admin']);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1020, maxHeight: 780),
        child: detail.when(
          loading: () => const SizedBox(height: 360, child: LoadingState()),
          error: (_, __) => ErrorState(
            message: 'No se pudo cargar el detalle.',
            onRetry: () => ref.invalidate(_purchaseRequestDetailProvider(requestId)),
          ),
          data: (data) {
            final request = Map<String, dynamic>.from(data['request'] as Map? ?? const {});
            final items = _list(data['items']);
            final requestSuppliers = _list(data['suppliers']);
            final quotes = _list(data['supplierQuotes']);
            final awards = _list(data['awards']);
            final number = request['number']?.toString() ?? requestId;
            final title = request['title']?.toString() ?? '';
            final suppliersById = {for (final supplier in suppliers) supplier.id: supplier};

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isNotEmpty ? title : number,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$number · ${request['document_type'] ?? request['documentType'] ?? 'PRESUPUESTO'}',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
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
                      _DetailSection(
                        title: 'Items solicitados',
                        children: items
                            .map((item) => _InfoLine(
                                  title: item['description']?.toString() ?? 'Item',
                                  subtitle: 'Cantidad ${item['quantity'] ?? '-'}',
                                  icon: Icons.inventory_2_outlined,
                                ))
                            .toList(),
                      ),
                      _DetailSection(
                        title: 'Proveedores invitados',
                        emptyText: 'Sin proveedores. Agregá uno antes de enviar.',
                        headerAction: AppButton.secondary(
                          label: 'Agregar proveedor',
                          icon: Icons.add_rounded,
                          onPressed: suppliers.isEmpty ? null : () => _addSupplier(context, ref, requestSuppliers, suppliers),
                        ),
                        children: requestSuppliers
                            .map((item) => _InfoLine(
                                  title: _supplierLabel(item['supplier_id']?.toString() ?? item['supplierId']?.toString(), suppliers),
                                  subtitle: item['status']?.toString() ?? 'DRAFT',
                                  icon: Icons.local_shipping_outlined,
                                  trailing: _SupplierContactActions(
                                    supplier: suppliersById[item['supplier_id']?.toString() ?? item['supplierId']?.toString()],
                                    publicToken: item['public_token']?.toString() ?? item['publicToken']?.toString(),
                                    number: number,
                                  ),
                                ))
                            .toList(),
                      ),
                      _DetailSection(
                        title: 'Comparacion y adjudicacion',
                        children: quotes
                            .map((quote) => _InfoLine(
                                  title: quote['quote_number']?.toString() ??
                                      quote['quoteNumber']?.toString() ??
                                      'Presupuesto proveedor',
                                  subtitle:
                                      '${_supplierLabel(quote['supplier_id']?.toString() ?? quote['supplierId']?.toString(), suppliers)} · ${quote['currency'] ?? 'ARS'} ${quote['total'] ?? '-'}',
                                  icon: Icons.price_change_outlined,
                                  trailing: canAward
                                      ? AppButton.secondary(
                                          label: 'Adjudicar',
                                          icon: Icons.verified_rounded,
                                          onPressed: () => _award(ref, quote),
                                        )
                                      : null,
                                ))
                            .toList(),
                      ),
                      if (awards.isNotEmpty)
                        _DetailSection(
                          title: 'Adjudicaciones',
                          children: awards
                              .map((award) => _InfoLine(
                                    title: _supplierLabel(award['supplier_id']?.toString(), suppliers),
                                    subtitle: '${award['mode'] ?? 'FULL'} · ${award['awarded_total'] ?? '-'}',
                                    icon: Icons.emoji_events_outlined,
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canSend)
                        AppButton.secondary(
                          label: 'Enviar',
                          icon: Icons.outgoing_mail,
                          onPressed: () => _send(ref),
                        ),
                      if (canQuote)
                        AppButton(
                          label: 'Cargar presupuesto',
                          icon: Icons.price_change_rounded,
                          onPressed: () => _openQuoteForm(context, ref, items, requestSuppliers, suppliers),
                        ),
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

  Future<void> _addSupplier(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> requestSuppliers,
    List<_LookupOption> suppliers,
  ) async {
    final linkedIds = requestSuppliers
        .map((item) => item['supplier_id']?.toString() ?? item['supplierId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final available = suppliers.where((supplier) => !linkedIds.contains(supplier.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No quedan proveedores disponibles para agregar.')));
      return;
    }
    final selected = await showModalBottomSheet<_LookupOption>(
      context: context,
      useSafeArea: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text('Agregar proveedor', style: TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...available.map((supplier) => ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(supplier.label),
                onTap: () => Navigator.of(context).pop(supplier),
              )),
        ],
      ),
    );
    if (selected == null) return;
    await ref.read(dioProvider).post(
      '/v1/purchase-requests/$requestId/suppliers',
      data: {'supplierId': selected.id},
    );
    ref.invalidate(_purchaseRequestDetailProvider(requestId));
    ref.invalidate(_purchaseRequestsProvider);
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
    List<Map<String, dynamic>> requestSuppliers,
    List<_LookupOption> suppliers,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SupplierQuoteSheet(
        requestId: requestId,
        items: items,
        requestSuppliers: requestSuppliers,
        suppliers: suppliers,
      ),
    );
    ref.invalidate(_purchaseRequestDetailProvider(requestId));
  }

  static String _publicSupplierUrl(String token) => 'https://backoffice.diceprojects.com/public/purchases/$token';

  static String _supplierMessage(String number, String token) =>
      'Hola, te enviamos la solicitud de presupuesto $number. Podés completar precios acá: ${_publicSupplierUrl(token)}';
}

class _SupplierContactActions extends StatelessWidget {
  final _LookupOption? supplier;
  final String? publicToken;
  final String number;

  const _SupplierContactActions({
    required this.supplier,
    required this.publicToken,
    required this.number,
  });

  @override
  Widget build(BuildContext context) {
    final token = publicToken?.trim() ?? '';
    if (token.isEmpty) return const SizedBox.shrink();
    final phone = _normalizeWhatsappPhone(supplier?.phone);
    final email = supplier?.email?.trim() ?? '';
    return Wrap(
      spacing: 2,
      children: [
        IconButton(
          tooltip: 'Abrir link',
          icon: const Icon(Icons.link_rounded),
          onPressed: () => _launchExternal(context, Uri.parse(_PurchaseRequestDetailDialog._publicSupplierUrl(token)), 'No se pudo abrir el link.'),
        ),
        IconButton(
          tooltip: phone.isEmpty ? 'Proveedor sin teléfono' : 'WhatsApp',
          icon: const Icon(Icons.chat_rounded),
          onPressed: phone.isEmpty
              ? null
              : () => _launchExternal(
                    context,
                    Uri.parse('https://api.whatsapp.com/send/?phone=$phone&text=${Uri.encodeComponent(_PurchaseRequestDetailDialog._supplierMessage(number, token))}&type=phone_number&app_absent=0'),
                    'No se pudo abrir WhatsApp.',
                  ),
        ),
        IconButton(
          tooltip: email.isEmpty ? 'Proveedor sin email' : 'Email',
          icon: const Icon(Icons.mail_outline_rounded),
          onPressed: email.isEmpty
              ? null
              : () => _launchExternal(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: email,
                      queryParameters: {
                        'subject': 'Solicitud de presupuesto $number',
                        'body': _PurchaseRequestDetailDialog._supplierMessage(number, token),
                      },
                    ),
                    'No se pudo abrir el email.',
                  ),
        ),
      ],
    );
  }
}

class _PurchaseRequestCreateSheet extends ConsumerStatefulWidget {
  const _PurchaseRequestCreateSheet();

  @override
  ConsumerState<_PurchaseRequestCreateSheet> createState() => _PurchaseRequestCreateSheetState();
}

class _PurchaseRequestCreateSheetState extends ConsumerState<_PurchaseRequestCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _currency = 'ARS';
  final _items = <_RequestItemDraft>[_RequestItemDraft()];
  final _supplierIds = <String>{};
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(_purchaseSuppliersProvider);
    final productsAsync = ref.watch(_purchaseProductsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.62,
      maxChildSize: 0.98,
      builder: (_, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Nueva solicitud de presupuesto', style: TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Tipo de comprobante: PRESUPUESTO', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            AppTextField(label: 'Titulo *', controller: _title, validator: _required),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Moneda'),
                    items: _currencyOptions.map((code) => DropdownMenuItem(value: code, child: Text(code))).toList(),
                    onChanged: _saving ? null : (value) => setState(() => _currency = value ?? 'ARS'),
                    validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: _DocumentTypeField()),
              ],
            ),
            const SizedBox(height: 10),
            AppTextField(label: 'Descripcion', controller: _description, maxLines: 3),
            const SizedBox(height: 18),
            _SheetTitle(
              title: 'Proveedores',
              action: IconButton(
                tooltip: 'Recargar proveedores',
                onPressed: () => ref.invalidate(_purchaseSuppliersProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            suppliersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('No se pudieron cargar proveedores.'),
              data: (suppliers) => _SupplierMultiSelector(
                suppliers: suppliers,
                selectedIds: _supplierIds,
                onChanged: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 18),
            _SheetTitle(
              title: 'Items',
              action: IconButton(
                tooltip: 'Agregar item',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => setState(() => _items.add(_RequestItemDraft())),
              ),
            ),
            for (var i = 0; i < _items.length; i++) ...[
              productsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => _RequestItemEditor(
                  item: _items[i],
                  products: const [],
                  index: i,
                  canRemove: _items.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _items.removeAt(i).dispose()),
                ),
                data: (products) => _RequestItemEditor(
                  item: _items[i],
                  products: products,
                  index: i,
                  canRemove: _items.length > 1,
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() => _items.removeAt(i).dispose()),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            AppButton(
              label: 'Crear solicitud',
              icon: Icons.add_rounded,
              isLoading: _saving,
              fullWidth: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final auth = ref.read(authNotifierProvider);
      await ref.read(dioProvider).post(
        '/v1/purchase-requests',
        data: {
          'tenantId': auth.tenantId,
          'sellerId': auth.sellerId,
          'documentType': 'PRESUPUESTO',
          'title': _title.text.trim(),
          'description': _emptyToNull(_description.text),
          'currency': _currency,
          'items': _items.map((item) => item.toJson()).toList(),
          'supplierIds': _supplierIds.toList(),
        },
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SupplierQuoteSheet extends ConsumerStatefulWidget {
  final String requestId;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> requestSuppliers;
  final List<_LookupOption> suppliers;

  const _SupplierQuoteSheet({
    required this.requestId,
    required this.items,
    required this.requestSuppliers,
    required this.suppliers,
  });

  @override
  ConsumerState<_SupplierQuoteSheet> createState() => _SupplierQuoteSheetState();
}

class _SupplierQuoteSheetState extends ConsumerState<_SupplierQuoteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quoteNumber = TextEditingController();
  final _taxes = TextEditingController(text: '0');
  final _deliveryDays = TextEditingController();
  final _paymentTerms = TextEditingController();
  final _notes = TextEditingController();
  final _prices = <String, TextEditingController>{};
  String? _supplierId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final allowed = _allowedSuppliers();
    if (allowed.isNotEmpty) _supplierId = allowed.first.id;
    for (final item in widget.items) {
      final id = item['id']?.toString() ?? '';
      if (id.isNotEmpty) _prices[id] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    _quoteNumber.dispose();
    _taxes.dispose();
    _deliveryDays.dispose();
    _paymentTerms.dispose();
    _notes.dispose();
    for (final controller in _prices.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = _allowedSuppliers();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.58,
      maxChildSize: 0.96,
      builder: (_, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Cargar presupuesto proveedor', style: TextStyle(color: AppColors.ink, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: suppliers.any((supplier) => supplier.id == _supplierId) ? _supplierId : null,
              decoration: const InputDecoration(labelText: 'Proveedor *'),
              items: suppliers
                  .map((supplier) => DropdownMenuItem(
                        value: supplier.id,
                        child: Text(supplier.label, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
              onChanged: _saving ? null : (value) => setState(() => _supplierId = value),
            ),
            const SizedBox(height: 10),
            AppTextField(label: 'Numero de presupuesto', controller: _quoteNumber),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: AppTextField(label: 'Impuestos', controller: _taxes, keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(label: 'Entrega dias', controller: _deliveryDays, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 10),
            AppTextField(label: 'Condicion de pago', controller: _paymentTerms),
            const SizedBox(height: 10),
            AppTextField(label: 'Notas', controller: _notes, maxLines: 3),
            const SizedBox(height: 18),
            const _SheetTitle(title: 'Precios por item'),
            for (final item in widget.items) ...[
              AppTextField(
                label: item['description']?.toString() ?? 'Item',
                hint: 'Cantidad ${item['quantity'] ?? '-'}',
                controller: _prices[item['id']?.toString()],
                keyboardType: TextInputType.number,
                validator: _requiredNumber,
              ),
              const SizedBox(height: 10),
            ],
            AppButton(
              label: 'Guardar presupuesto',
              icon: Icons.save_rounded,
              isLoading: _saving,
              fullWidth: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  List<_LookupOption> _allowedSuppliers() {
    final invitedIds = widget.requestSuppliers
        .map((item) => item['supplier_id']?.toString() ?? item['supplierId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    if (invitedIds.isEmpty) return widget.suppliers;
    return widget.suppliers.where((supplier) => invitedIds.contains(supplier.id)).toList();
  }

  String? _requiredNumber(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null ? 'Numero requerido' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final quoteItems = widget.items.map((item) {
        final id = item['id']?.toString() ?? '';
        final quantity = _num(item['quantity']) ?? 0;
        final unitPrice = _num(_prices[id]?.text) ?? 0;
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
          'supplierId': _supplierId,
          'quoteNumber': _emptyToNull(_quoteNumber.text),
          'currency': 'ARS',
          'taxes': _num(_taxes.text) ?? 0,
          'deliveryDays': int.tryParse(_deliveryDays.text.trim()),
          'paymentTerms': _emptyToNull(_paymentTerms.text),
          'notes': _emptyToNull(_notes.text),
          'items': quoteItems,
        },
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SupplierMultiSelector extends StatelessWidget {
  final List<_LookupOption> suppliers;
  final Set<String> selectedIds;
  final VoidCallback onChanged;

  const _SupplierMultiSelector({
    required this.suppliers,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (suppliers.isEmpty) {
      return Text('No hay proveedores activos para seleccionar.', style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      children: suppliers
          .map(
            (supplier) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: selectedIds.contains(supplier.id),
              title: Text(supplier.label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                if (value == true) {
                  selectedIds.add(supplier.id);
                } else {
                  selectedIds.remove(supplier.id);
                }
                onChanged();
              },
            ),
          )
          .toList(),
    );
  }
}

class _RequestItemEditor extends StatelessWidget {
  final _RequestItemDraft item;
  final List<_ProductOption> products;
  final int index;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _RequestItemEditor({
    required this.item,
    required this.products,
    required this.index,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Item ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800))),
              if (canRemove)
                IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onRemove,
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: products.any((product) => product.id == item.productId) ? item.productId : null,
            decoration: const InputDecoration(labelText: 'Artículo *'),
            items: products
                .map((product) => DropdownMenuItem(
                      value: product.id,
                      child: Text(product.label, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) {
              _ProductOption? selected;
              for (final product in products) {
                if (product.id == value) {
                  selected = product;
                  break;
                }
              }
              item.productId = selected?.id;
              if (selected != null) item.description.text = selected.name;
              onChanged();
            },
            validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
          ),
          const SizedBox(height: 10),
          AppTextField(label: 'Nombre para proveedor *', controller: item.description, validator: _required),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: AppTextField(label: 'Cantidad *', controller: item.quantity, keyboardType: TextInputType.number, validator: _requiredNumber)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unitOptions.contains(item.unit) ? item.unit : 'UN',
                  decoration: const InputDecoration(labelText: 'Unidad'),
                  items: _unitOptions.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                  onChanged: (value) {
                    item.unit = value ?? 'UN';
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(label: 'Notas', controller: item.notes, maxLines: 2),
        ],
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Requerido' : null;

  String? _requiredNumber(String? value) {
    final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
    return parsed == null || parsed <= 0 ? 'Cantidad requerida' : null;
  }
}

class _DocumentTypeField extends StatelessWidget {
  const _DocumentTypeField();

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: 'PRESUPUESTO',
      decoration: const InputDecoration(labelText: 'Tipo comprobante'),
      items: const [
        DropdownMenuItem(value: 'PRESUPUESTO', child: Text('Presupuesto')),
      ],
      onChanged: null,
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? headerAction;
  final String? emptyText;

  const _DetailSection({required this.title, required this.children, this.headerAction, this.emptyText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              if (headerAction != null) headerAction!,
            ],
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            Text(emptyText ?? 'Sin datos.', style: TextStyle(color: AppColors.textSecondary))
          else
            ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _InfoLine({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SheetTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        if (action != null) action!,
      ],
    );
  }
}

class _PurchaseRequestDto {
  final String id;
  final String number;
  final String documentType;
  final String title;
  final String status;
  final String currency;

  const _PurchaseRequestDto({
    required this.id,
    required this.number,
    required this.documentType,
    required this.title,
    required this.status,
    required this.currency,
  });

  factory _PurchaseRequestDto.fromJson(Map<String, dynamic> json) {
    return _PurchaseRequestDto(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? 'Sin numero',
      documentType: (json['document_type'] ?? json['documentType'])?.toString() ?? 'PRESUPUESTO',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'DRAFT',
      currency: json['currency']?.toString() ?? 'ARS',
    );
  }
}

class _LookupOption {
  final String id;
  final String label;
  final String? phone;
  final String? email;

  const _LookupOption({required this.id, required this.label, this.phone, this.email});

  factory _LookupOption.supplier(Map<String, dynamic> json) {
    final name = json['businessName']?.toString() ?? json['tradeName']?.toString() ?? 'Proveedor';
    final code = json['code']?.toString() ?? '';
    return _LookupOption(
      id: (json['supplierId'] ?? json['id'])?.toString() ?? '',
      label: code.isEmpty ? name : '$code · $name',
      phone: (json['phone'] ?? json['contactPhone'])?.toString(),
      email: (json['email'] ?? json['contactEmail'])?.toString(),
    );
  }
}

class _ProductOption {
  final String id;
  final String name;
  final String sku;

  const _ProductOption({required this.id, required this.name, required this.sku});

  String get label => sku.isEmpty ? name : '$name · $sku';

  factory _ProductOption.fromJson(Map<String, dynamic> json) => _ProductOption(
        id: (json['productId'] ?? json['id'])?.toString() ?? '',
        name: (json['name'] ?? json['productName'])?.toString() ?? '',
        sku: (json['sku'] ?? json['code'])?.toString() ?? '',
      );
}

class _RequestItemDraft {
  String? productId;
  final description = TextEditingController();
  final quantity = TextEditingController(text: '1');
  String unit = 'UN';
  final notes = TextEditingController();

  void dispose() {
    description.dispose();
    quantity.dispose();
    notes.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': _emptyToNull(productId ?? ''),
      'description': description.text.trim(),
      'quantity': _num(quantity.text) ?? 1,
      'unitId': unit,
      'notes': _emptyToNull(notes.text),
    };
  }
}

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is List) {
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  if (raw is Map && raw['content'] is List) {
    return (raw['content'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }
  return const [];
}

String _supplierLabel(String? id, List<_LookupOption> suppliers) {
  if (id == null || id.isEmpty) return 'Proveedor';
  for (final supplier in suppliers) {
    if (supplier.id == id) return supplier.label;
  }
  return id;
}

String? _emptyToNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _normalizeWhatsappPhone(String? value, {String defaultCountryCode = '54'}) {
  var digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith(defaultCountryCode)) return digits;
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  return '$defaultCountryCode$digits';
}

Future<void> _launchExternal(BuildContext context, Uri uri, String errorMessage) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}

double? _num(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().replaceAll(',', '.'));
}
