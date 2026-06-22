import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/confirm_dialog.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class QuoteDto {
  final String id;
  final String number;
  final String status;
  final String? publicToken;
  final String? pdfUrl;
  final String? sellerName;
  final String customerFirstName;
  final String? customerLastName;
  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? source;
  final String? notes;
  final String currency;
  final double total;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final List<QuoteItemDto> items;

  const QuoteDto({
    required this.id,
    required this.number,
    required this.status,
    this.publicToken,
    this.pdfUrl,
    this.sellerName,
    required this.customerFirstName,
    this.customerLastName,
    required this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.source,
    this.notes,
    required this.currency,
    required this.total,
    this.createdAt,
    this.expiresAt,
    required this.items,
  });

  factory QuoteDto.fromJson(Map<String, dynamic> json) {
    final first = (json['customerFirstName'] ?? '').toString().trim();
    final last = (json['customerLastName'] ?? '').toString().trim();
    final fullName = [
      if (first.isNotEmpty) first,
      if (last.isNotEmpty) last,
    ].join(' ');
    final rawItems = (json['items'] as List?) ?? const [];
    return QuoteDto(
      id: (json['quoteId'] ?? json['id'] ?? '').toString(),
      number: (json['quoteNumber'] ?? json['number'] ?? '').toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      publicToken: json['publicToken']?.toString(),
      pdfUrl: _nonEmpty(json['pdfUrl']),
      sellerName: json['sellerName']?.toString(),
      customerFirstName: first.isNotEmpty ? first : fullName,
      customerLastName: _nonEmpty(json['customerLastName']),
      customerName: fullName.isNotEmpty ? fullName : 'Cliente sin nombre',
      customerEmail: _nonEmpty(json['customerEmail']),
      customerPhone: _nonEmpty(json['customerPhone']),
      source: _nonEmpty(json['source']),
      notes: _nonEmpty(json['notes']),
      currency: (json['currencyCode'] ?? json['currency'] ?? 'ARS').toString(),
      total: _parseDouble(json['totalAmount'] ?? json['total']),
      createdAt: _parseDate(json['createdDate'] ?? json['createdAt']),
      expiresAt: _parseDate(json['expiresAt'] ?? json['validUntil']),
      items: rawItems
          .map((item) => QuoteItemDto.fromJson(
                item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map),
              ))
          .toList(),
    );
  }

  bool get hasPublicLink =>
      publicToken != null && publicToken!.trim().isNotEmpty && status == 'SENT';

  String get publicUrl =>
      'https://backoffice.diceprojects.com/public/quotes/${publicToken ?? ''}';

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class QuoteItemDto {
  final String? quoteItemId;
  final String? productId;
  final String productName;
  final String? productSku;
  final String? color;
  final String? presentation;
  final String? purchaseMode;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double lineTotal;

  const QuoteItemDto({
    this.quoteItemId,
    this.productId,
    required this.productName,
    this.productSku,
    this.color,
    this.presentation,
    this.purchaseMode,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory QuoteItemDto.fromJson(Map<String, dynamic> json) => QuoteItemDto(
        quoteItemId: json['quoteItemId']?.toString(),
        productId: json['productId']?.toString(),
        productName:
            (json['productName'] ?? json['name'] ?? 'Producto').toString(),
        productSku: (json['productSku'] ?? json['sku'])?.toString(),
        color: json['color']?.toString(),
        presentation: json['presentation']?.toString(),
        purchaseMode: json['purchaseMode']?.toString(),
        quantity: QuoteDto._parseDouble(json['quantity']),
        unit: (json['unit'] ?? 'U').toString(),
        unitPrice: QuoteDto._parseDouble(json['unitPrice']),
        lineTotal: QuoteDto._parseDouble(json['lineTotal'] ?? json['total']),
      );
}

class QuotesNotifier extends ListNotifier<QuoteDto> {
  final Dio _dio;
  String? _status;

  QuotesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<QuoteDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/quotes',
      queryParameters: {
        ...params.toQueryParams(),
        if (_status != null && _status!.isNotEmpty) 'status': _status,
      },
    );
    return PaginatedResponse.fromJson(resp.data, QuoteDto.fromJson);
  }

  void setStatus(String? status) {
    _status = status;
    loadPage(0);
  }

  Future<void> updateStatus(QuoteDto quote, String status) async {
    await _dio.patch(
      '/v1/quotes/${quote.id}/status',
      data: {'status': status},
    );
    reload();
  }

  Future<QuoteDto> updateQuote(
      QuoteDto quote, Map<String, dynamic> payload) async {
    final resp = await _dio.put('/v1/quotes/${quote.id}', data: payload);
    final updated =
        QuoteDto.fromJson(Map<String, dynamic>.from(resp.data as Map));
    reload();
    return updated;
  }

  Future<void> delete(QuoteDto quote) async {
    await _dio.delete('/v1/quotes/${quote.id}');
    reload();
  }

  Future<void> createManual(Map<String, dynamic> payload) async {
    await _dio.post('/v1/quotes', data: payload);
    reload();
  }

  Future<void> createPurchaseRequest(
      QuoteDto quote, Map<String, dynamic> payload) async {
    await _dio.post('/v1/quotes/${quote.id}/purchase-request', data: payload);
    reload();
  }
}

final quotesNotifierProvider =
    StateNotifierProvider.autoDispose<QuotesNotifier, ListState<QuoteDto>>(
  (ref) => QuotesNotifier(ref.watch(dioProvider)),
);

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quotesNotifierProvider);
    final notifier = ref.read(quotesNotifierProvider.notifier);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission([
      'Sales.Create',
      'Sales.Quotes.Create',
      'Sales.Admin',
    ]);

    return AppPageScaffold(
      title: 'Cotizaciones',
      searchHint: 'Buscar cliente o número…',
      onSearch: notifier.setSearch,
      actions: [
        IconButton(
          tooltip: 'Actualizar',
          onPressed: notifier.reload,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton: canCreate
          ? CreateFab(
              label: 'Nueva cotización',
              onPressed: () => _openCreate(context, ref),
            )
          : null,
      body: Column(
        children: [
          _StatusFilters(onChanged: notifier.setStatus),
          Expanded(child: _QuotesBody(state: state, notifier: notifier)),
        ],
      ),
    );
  }

  void _openCreate(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _QuoteCreateSheet(),
    );
  }
}

class _LookupOption {
  final String id;
  final String label;

  const _LookupOption({required this.id, required this.label});

  factory _LookupOption.tenant(Map<String, dynamic> json) => _LookupOption(
        id: (json['tenantId'] ?? json['id'] ?? '').toString(),
        label: (json['name'] ?? json['code'] ?? 'Empresa').toString(),
      );

  factory _LookupOption.seller(Map<String, dynamic> json) => _LookupOption(
        id: (json['sellerId'] ?? json['id'] ?? '').toString(),
        label: (json['name'] ??
                json['sellerName'] ??
                json['sellerCode'] ??
                'Seller')
            .toString(),
      );
}

_LookupOption _lookupTenant(String id, String label) =>
    _LookupOption(id: id, label: label);

_LookupOption _lookupSeller(String id, String label) =>
    _LookupOption(id: id, label: label);

class _QuoteProductOption {
  final String id;
  final String name;
  final String sku;
  final double basePrice;
  final double discountPercent;
  final double suggestedPrice;
  final List<String> colors;
  final List<String> presentations;

  const _QuoteProductOption({
    required this.id,
    required this.name,
    required this.sku,
    required this.basePrice,
    required this.discountPercent,
    required this.suggestedPrice,
    this.colors = const [],
    this.presentations = const [],
  });

  factory _QuoteProductOption.fromJson(Map<String, dynamic> json) {
    final basePrice = _parseFirstAmount(
      json,
      [
        'basePrice',
        'price',
        'unitPrice',
        'retailPrice',
        'wholesalePrice',
        'amount'
      ],
    );
    final discount = _parseFirstAmount(
        json, ['discountPercent', 'discount', 'discountRate']);
    final explicitSuggested = _parseFirstAmount(
      json,
      [
        'salePrice',
        'finalPrice',
        'discountedPrice',
        'currentPrice',
        'effectivePrice',
        'offerPrice'
      ],
    );
    final calculated = discount > 0
        ? basePrice * (1 - (discount.clamp(0, 100).toDouble() / 100))
        : basePrice;
    return _QuoteProductOption(
      id: (json['productId'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['productName'] ?? 'Producto').toString(),
      sku: (json['sku'] ?? json['code'] ?? '').toString(),
      basePrice: basePrice,
      discountPercent: discount,
      suggestedPrice: explicitSuggested > 0 ? explicitSuggested : calculated,
      colors: _readOptionList(
          json, const ['colors', 'colorOptions', 'availableColors']),
      presentations: _readOptionList(json, const [
        'presentations',
        'presentationOptions',
        'availablePresentations'
      ]),
    );
  }

  String get label => sku.trim().isEmpty ? name : '$name · $sku';
}

List<String> _readOptionList(Map<String, dynamic> json, List<String> keys) {
  final values = <String>{};
  for (final key in keys) {
    final raw = json[key];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final text = (item['name'] ??
                  item['code'] ??
                  item['presentationTypeCode'] ??
                  item['unitCode'] ??
                  item['value'])
              ?.toString()
              .trim();
          if (text != null && text.isNotEmpty) values.add(text.toUpperCase());
        } else {
          final text = item.toString().trim();
          if (text.isNotEmpty) values.add(text.toUpperCase());
        }
      }
    } else if (raw is String) {
      for (final part in raw.split(',')) {
        final text = part.trim();
        if (text.isNotEmpty) values.add(text.toUpperCase());
      }
    }
  }
  return values.toList();
}

final _quoteTenantsProvider =
    FutureProvider.autoDispose<List<_LookupOption>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAdminGlobal &&
      auth.tenantId != null &&
      auth.tenantId!.trim().isNotEmpty) {
    return [_lookupTenant(auth.tenantId!, 'Empresa asociada')];
  }
  final resp = await ref.watch(dioProvider).get('/v1/tenants',
      queryParameters: const {'page': 0, 'size': 200, 'pageSize': 200});
  return PaginatedResponse.fromJson(resp.data, _LookupOption.tenant).items;
});

final _quoteSellersProvider = FutureProvider.autoDispose
    .family<List<_LookupOption>, String>((ref, tenantId) async {
  if (tenantId.trim().isEmpty) return const [];
  final auth = ref.watch(authNotifierProvider);
  if (!auth.isAdminGlobal) {
    final sellerId = auth.sellerId?.trim();
    if (sellerId != null && sellerId.isNotEmpty) {
      return [_lookupSeller(sellerId, 'Seller asociado')];
    }
    final sellerIds = auth.sellerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (sellerIds.length == 1) {
      return [_lookupSeller(sellerIds.first, 'Seller asociado')];
    }
  }
  final resp = await ref.watch(dioProvider).get(
    '/v1/sellers',
    queryParameters: {
      'tenantId': tenantId,
      'page': 0,
      'size': 200,
      'pageSize': 200,
      'active': true
    },
  );
  return PaginatedResponse.fromJson(resp.data, _LookupOption.seller).items;
});

final _quoteProductsProvider = FutureProvider.autoDispose
    .family<List<_QuoteProductOption>, String?>((ref, sellerId) async {
  final query = <String, dynamic>{
    'page': 0,
    'size': 500,
    'pageSize': 500,
    if (sellerId != null && sellerId.trim().isNotEmpty)
      'sellerId': sellerId.trim(),
  };
  final resp =
      await ref.watch(dioProvider).get('/v1/products', queryParameters: query);
  return PaginatedResponse.fromJson(resp.data, _QuoteProductOption.fromJson)
      .items;
});

class _QuoteCreateSheet extends ConsumerStatefulWidget {
  const _QuoteCreateSheet();

  @override
  ConsumerState<_QuoteCreateSheet> createState() => _QuoteCreateSheetState();
}

class _QuoteCreateSheetState extends ConsumerState<_QuoteCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _product = TextEditingController();
  final _sku = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _unit = TextEditingController(text: 'U');
  final _suggestedPrice = TextEditingController(text: '0');
  final _price = TextEditingController(text: '0');
  final _color = TextEditingController();
  final _presentation = TextEditingController();
  final _notes = TextEditingController();
  String? _tenantId;
  String? _sellerId;
  String? _productId;
  String _purchaseMode = 'PENDING';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAdminGlobal) {
      final tenantId = auth.tenantId?.trim();
      if (tenantId != null && tenantId.isNotEmpty) {
        _tenantId = tenantId;
      }
      final sellerId = auth.sellerId?.trim();
      if (sellerId != null && sellerId.isNotEmpty) {
        _sellerId = sellerId;
      } else {
        final sellerIds = auth.sellerIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList();
        if (sellerIds.length == 1) {
          _sellerId = sellerIds.first;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      _firstName,
      _lastName,
      _phone,
      _email,
      _product,
      _sku,
      _quantity,
      _unit,
      _suggestedPrice,
      _price,
      _color,
      _presentation,
      _notes
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    if (!auth.isAdminGlobal &&
        (_tenantId == null || _tenantId!.trim().isEmpty) &&
        auth.tenantId?.trim().isNotEmpty == true) {
      _tenantId = auth.tenantId!.trim();
    }
    if (!auth.isAdminGlobal &&
        (_sellerId == null || _sellerId!.trim().isEmpty)) {
      final sellerId = auth.sellerId?.trim();
      if (sellerId != null && sellerId.isNotEmpty) {
        _sellerId = sellerId;
      } else if (auth.sellerIds.length == 1) {
        _sellerId = auth.sellerIds.first.trim();
      }
    }
    final tenantsAsync = ref.watch(_quoteTenantsProvider);
    final sellersAsync = _tenantId == null || _tenantId!.trim().isEmpty
        ? const AsyncData<List<_LookupOption>>([])
        : ref.watch(_quoteSellersProvider(_tenantId!));
    final productsAsync = _sellerId == null || _sellerId!.trim().isEmpty
        ? const AsyncData<List<_QuoteProductOption>>([])
        : ref.watch(_quoteProductsProvider(_sellerId));
    final selectedProduct = _findQuoteProduct(
      productsAsync.asData?.value ?? const [],
      _productId,
    );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.60,
      maxChildSize: 0.98,
      builder: (_, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Nueva cotización',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            tenantsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) =>
                  Text('No se pudieron cargar empresas: $error'),
              data: (tenants) {
                if (_tenantId == null && tenants.length == 1) {
                  _tenantId = tenants.first.id;
                }
                if (!auth.isAdminGlobal && _tenantId != null) {
                  _LookupOption? tenant;
                  for (final item in tenants) {
                    if (item.id == _tenantId) {
                      tenant = item;
                      break;
                    }
                  }
                  return _ReadOnlyScopeField(
                    label: 'Empresa',
                    value: tenant?.label ?? 'Empresa asociada',
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _tenantId,
                  decoration: const InputDecoration(labelText: 'Empresa *'),
                  items: tenants
                      .map((t) => DropdownMenuItem(
                          value: t.id,
                          child:
                              Text(t.label, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _tenantId = value;
                            _sellerId = null;
                            _productId = null;
                          }),
                );
              },
            ),
            const SizedBox(height: 12),
            sellersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) =>
                  Text('No se pudieron cargar sellers: $error'),
              data: (sellers) {
                if (_sellerId == null && sellers.length == 1) {
                  _sellerId = sellers.first.id;
                }
                if (!auth.isAdminGlobal &&
                    _sellerId != null &&
                    sellers.length == 1) {
                  return _ReadOnlyScopeField(
                    label: 'Seller',
                    value: sellers.first.label,
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: _sellerId,
                  decoration: const InputDecoration(labelText: 'Seller *'),
                  items: sellers
                      .map((s) => DropdownMenuItem(
                          value: s.id,
                          child:
                              Text(s.label, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                            _sellerId = value;
                            _productId = null;
                          }),
                );
              },
            ),
            const SizedBox(height: 16),
            const _SectionTitle('Cliente'),
            AppTextField(
                label: 'Nombre *',
                controller: _firstName,
                validator: _required),
            const SizedBox(height: 10),
            AppTextField(label: 'Apellido', controller: _lastName),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Teléfono *',
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: _required),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            const _SectionTitle('Producto'),
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (products) => products.isEmpty
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<String>(
                      initialValue:
                          products.any((product) => product.id == _productId)
                              ? _productId
                              : null,
                      decoration: const InputDecoration(
                          labelText: 'Producto de catálogo'),
                      items: products
                          .map((product) => DropdownMenuItem(
                                value: product.id,
                                child: Text(product.label,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                                _productId = value;
                                final selected =
                                    _findQuoteProduct(products, value);
                                if (selected == null) return;
                                _product.text = selected.name;
                                _sku.text = selected.sku;
                                _suggestedPrice.text =
                                    _plainNumber(selected.suggestedPrice);
                                _price.text =
                                    _plainNumber(selected.suggestedPrice);
                                if (selected.colors.isNotEmpty &&
                                    _color.text.trim().isEmpty) {
                                  _color.text = selected.colors.first;
                                }
                                if (selected.presentations.isNotEmpty &&
                                    _presentation.text.trim().isEmpty) {
                                  _presentation.text =
                                      selected.presentations.first;
                                }
                              }),
                    ),
            ),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Producto *',
                controller: _product,
                validator: _required),
            const SizedBox(height: 10),
            AppTextField(label: 'SKU', controller: _sku),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: AppTextField(
                        label: 'Cantidad *',
                        controller: _quantity,
                        keyboardType: TextInputType.number,
                        validator: _required)),
                const SizedBox(width: 10),
                Expanded(
                    child: AppTextField(label: 'Unidad', controller: _unit)),
              ],
            ),
            const SizedBox(height: 10),
            AppTextField(
              label: 'Precio sugerido',
              controller: _suggestedPrice,
              keyboardType: TextInputType.number,
              readOnly: true,
            ),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Precio cotizado',
                controller: _price,
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuoteOptionField(
                    label: 'Color',
                    controller: _color,
                    options: selectedProduct?.colors ?? const [],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuoteOptionField(
                    label: 'Presentación',
                    controller: _presentation,
                    options: selectedProduct?.presentations ?? const [],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _purchaseMode,
              decoration: const InputDecoration(labelText: 'Tipo de venta'),
              items: const [
                DropdownMenuItem(value: 'PENDING', child: Text('Pendiente')),
                DropdownMenuItem(value: 'WHOLESALE', child: Text('Por mayor')),
                DropdownMenuItem(value: 'RETAIL', child: Text('Por menor')),
              ],
              onChanged: _saving
                  ? null
                  : (value) =>
                      setState(() => _purchaseMode = value ?? 'PENDING'),
            ),
            const SizedBox(height: 10),
            AppTextField(label: 'Notas', controller: _notes, maxLines: 3),
            const SizedBox(height: 18),
            AppButton(
              label: 'Crear cotización',
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAdminGlobal) {
      _tenantId ??= auth.tenantId?.trim();
      _sellerId ??= auth.sellerId?.trim();
      if ((_sellerId == null || _sellerId!.trim().isEmpty) &&
          auth.sellerIds.length == 1) {
        _sellerId = auth.sellerIds.first.trim();
      }
    }
    if (_tenantId == null || _tenantId!.trim().isEmpty) {
      _showSnack(context, 'No pudimos resolver la empresa de la sesión.');
      return;
    }
    if (_sellerId == null || _sellerId!.trim().isEmpty) {
      _showSnack(context, 'Seleccioná un seller para crear la cotización.');
      return;
    }
    setState(() => _saving = true);
    try {
      final quantity =
          double.tryParse(_quantity.text.replaceAll(',', '.')) ?? 1;
      final price = double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;
      final payload = {
        'tenantId': _tenantId!.trim(),
        'companyId': _tenantId!.trim(),
        'sellerId': _sellerId!.trim(),
        'customerFirstName': _firstName.text.trim(),
        'customerLastName': _lastName.text.trim(),
        'customerPhone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'customerEmail': _email.text.trim(),
        'source': 'MOBILE_BACKOFFICE',
        'currencyCode': 'ARS',
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'items': [
          {
            'productId': _productId ??
                (_sku.text.trim().isNotEmpty
                    ? _sku.text.trim()
                    : 'MOBILE-MANUAL'),
            'productSku': _sku.text.trim(),
            'productName': _product.text.trim(),
            'color': _color.text.trim(),
            'presentation': _presentation.text.trim(),
            'purchaseMode': _purchaseMode,
            'quantity': quantity,
            'unit': _unit.text.trim().isEmpty
                ? 'U'
                : _unit.text.trim().toUpperCase(),
            'unitPrice': price,
          }
        ],
      };
      await ref.read(quotesNotifierProvider.notifier).createManual(payload);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _ReadOnlyScopeField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyScopeField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusFilters extends StatefulWidget {
  final ValueChanged<String?> onChanged;

  const _StatusFilters({required this.onChanged});

  @override
  State<_StatusFilters> createState() => _StatusFiltersState();
}

class _StatusFiltersState extends State<_StatusFilters> {
  String? _selected;
  static const _items = <String?>[
    null,
    'DRAFT',
    'SENT',
    'ANSWERED',
    'WON',
    'LOST',
    'EXPIRED',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final value = _items[index];
          final active = value == _selected;
          return ChoiceChip(
            selected: active,
            label: Text(value == null ? 'Todas' : _statusLabel(value)),
            onSelected: (_) {
              setState(() => _selected = value);
              widget.onChanged(value);
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: _items.length,
      ),
    );
  }
}

class _QuotesBody extends ConsumerWidget {
  final ListState<QuoteDto> state;
  final QuotesNotifier notifier;

  const _QuotesBody({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las cotizaciones',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.request_quote_outlined,
        title: 'Sin cotizaciones',
        message: 'No hay solicitudes para los filtros seleccionados.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 92),
          itemBuilder: (_, index) {
            if (index == state.items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: LoadingState(asSkeleton: false),
              );
            }
            return _QuoteCard(quote: state.items[index]);
          },
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  final QuoteDto quote;

  const _QuoteCard({required this.quote});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(context, ref),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.number.isEmpty ? 'Cotización' : quote.number,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StatusBadge(status: quote.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                quote.customerName,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (quote.sellerName != null) quote.sellerName,
                  if (quote.createdAt != null) _formatDate(quote.createdAt!),
                ].whereType<String>().join(' · '),
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(label: 'Items', value: '${quote.items.length}'),
                  const SizedBox(width: 8),
                  _MiniMetric(label: 'Origen', value: quote.source ?? '-'),
                  const Spacer(),
                  Text(
                    _money(quote.total, quote.currency),
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _QuoteDetailSheet(quote: quote),
    );
  }
}

class _QuoteDetailSheet extends ConsumerStatefulWidget {
  final QuoteDto quote;

  const _QuoteDetailSheet({required this.quote});

  @override
  ConsumerState<_QuoteDetailSheet> createState() => _QuoteDetailSheetState();
}

class _QuoteDetailSheetState extends ConsumerState<_QuoteDetailSheet> {
  late String _status = widget.quote.status;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final canStatus = perms.hasAnyPermission([
      'Sales.Status',
      'Sales.Quotes.Status',
      'Sales.Admin',
    ]);
    final canEdit = perms.hasAnyPermission([
      'Sales.Edit',
      'Sales.Quotes.Edit',
      'Sales.Quotes.Create',
      'Sales.Admin',
    ]);
    final canDelete = perms.hasAnyPermission([
      'Sales.Delete',
      'Sales.Quotes.Delete',
      'Sales.Admin',
    ]);
    final canCreatePurchaseRequest = perms.hasAnyPermission([
      'Sales.Quotes.PurchaseRequest.Create',
      'Sales.Admin',
    ]);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      minChildSize: 0.55,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.quote.number,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      widget.quote.customerName,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _money(widget.quote.total, widget.quote.currency),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CustomerPanel(quote: widget.quote),
          if (canEdit) ...[
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Editar cotización',
              icon: Icons.edit_rounded,
              fullWidth: true,
              onPressed: _saving ? null : _openEditSheet,
            ),
          ],
          if (canCreatePurchaseRequest) ...[
            const SizedBox(height: 12),
            AppButton.secondary(
              label: 'Generar solicitud de compra',
              icon: Icons.assignment_turned_in_rounded,
              fullWidth: true,
              onPressed: _saving ? null : _openPurchaseRequestDialog,
            ),
          ],
          if (widget.quote.expiresAt != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.event_available_rounded,
              label: 'Vigencia',
              value: _formatDate(widget.quote.expiresAt!),
            ),
          ],
          const SizedBox(height: 18),
          if (canStatus) ...[
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Estado'),
              items: const ['DRAFT', 'SENT', 'ANSWERED', 'WON', 'LOST']
                  .map(
                    (status) => DropdownMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        if (value != null) _status = value;
                      }),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving || _status == widget.quote.status
                    ? null
                    : _saveStatus,
                icon: const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Guardando...' : 'Guardar estado'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Items cotizados',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in widget.quote.items) ...[
            _QuoteItemCard(item: item, currency: widget.quote.currency),
            const SizedBox(height: 10),
          ],
          if (widget.quote.notes != null) ...[
            const SizedBox(height: 8),
            _NotesPanel(notes: widget.quote.notes!),
          ],
          const SizedBox(height: 14),
          if (widget.quote.hasPublicLink)
            _PublicQrPanel(url: widget.quote.publicUrl)
          else
            _LockedLinkPanel(status: widget.quote.status),
          if (widget.quote.status == 'SENT' ||
              widget.quote.status == 'DRAFT') ...[
            const SizedBox(height: 12),
            _QuoteDeliveryActions(quote: widget.quote),
          ],
          if (canDelete) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _saving ? null : _deleteQuote,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Eliminar cotización'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openEditSheet() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QuoteEditSheet(quote: widget.quote),
    );
    if (mounted && updated == true) Navigator.of(context).pop();
  }

  Future<void> _saveStatus() async {
    if (_status == 'SENT' &&
        widget.quote.items.any((item) => item.unitPrice <= 0)) {
      _showSnack(
        context,
        'Para enviar, todos los productos deben tener precio cotizado mayor a 0.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(quotesNotifierProvider.notifier)
          .updateStatus(widget.quote, _status);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPurchaseRequestDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _QuotePurchaseRequestDialog(quote: widget.quote),
    );
    if (mounted && created == true) Navigator.of(context).pop();
  }

  Future<void> _deleteQuote() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Eliminar cotización',
      message: 'Se ocultará de la operación diaria. ¿Querés continuar?',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    setState(() => _saving = true);
    try {
      await ref.read(quotesNotifierProvider.notifier).delete(widget.quote);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _QuoteEditSheet extends ConsumerStatefulWidget {
  final QuoteDto quote;

  const _QuoteEditSheet({required this.quote});

  @override
  ConsumerState<_QuoteEditSheet> createState() => _QuoteEditSheetState();
}

class _QuotePurchaseRequestDialog extends ConsumerStatefulWidget {
  final QuoteDto quote;

  const _QuotePurchaseRequestDialog({required this.quote});

  @override
  ConsumerState<_QuotePurchaseRequestDialog> createState() =>
      _QuotePurchaseRequestDialogState();
}

class _QuotePurchaseRequestDialogState
    extends ConsumerState<_QuotePurchaseRequestDialog> {
  final _title = TextEditingController();
  final _validUntil = TextEditingController();
  late final Set<String> _selectedItemIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title.text = 'Presupuesto proveedores ${widget.quote.number}';
    _selectedItemIds = widget.quote.items
        .map((item) => item.quoteItemId)
        .whereType<String>()
        .where((id) => id.trim().isNotEmpty)
        .toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _validUntil.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Solicitud de compra'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              TextField(
                controller: _validUntil,
                decoration: const InputDecoration(
                  labelText: 'Válido hasta',
                  helperText: 'Formato opcional: 2026-06-30T18:00:00',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Se crea como borrador en Compras. Revisá la solicitud, asociá proveedor y enviá desde el módulo de Compras.',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Items',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final item in widget.quote.items)
                CheckboxListTile(
                  value: _selectedItemIds.contains(item.quoteItemId),
                  onChanged: item.quoteItemId == null
                      ? null
                      : (value) => setState(() {
                            if (value == true) {
                              _selectedItemIds.add(item.quoteItemId!);
                            } else {
                              _selectedItemIds.remove(item.quoteItemId);
                            }
                          }),
                  title: Text(item.productName),
                  subtitle: Text('${item.quantity} ${item.unit}'),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.assignment_turned_in_rounded),
          label: const Text('Generar'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_selectedItemIds.isEmpty) {
      _showSnack(context, 'Seleccioná al menos un item.');
      return;
    }
    setState(() => _saving = true);
    final validUntilText = _validUntil.text.trim();
    await ref.read(quotesNotifierProvider.notifier).createPurchaseRequest(
      widget.quote,
      {
        'title': _title.text.trim(),
        'description':
            'Generado desde cotización ${widget.quote.number}. Completar proveedor y envío desde Compras.',
        'validUntil': validUntilText.isEmpty ? null : validUntilText,
        'quoteItemIds': _selectedItemIds.toList(),
        'supplierIds': const <String>[],
      },
    );
    if (mounted) Navigator.of(context).pop(true);
  }
}

class _QuoteEditSheetState extends ConsumerState<_QuoteEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _notes;
  late final TextEditingController _expiresAt;
  late final List<_QuoteItemEditControllers> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.quote.customerFirstName);
    _lastName =
        TextEditingController(text: widget.quote.customerLastName ?? '');
    _phone = TextEditingController(text: widget.quote.customerPhone ?? '');
    _email = TextEditingController(text: widget.quote.customerEmail ?? '');
    _notes = TextEditingController(text: widget.quote.notes ?? '');
    _expiresAt = TextEditingController(
      text: widget.quote.expiresAt == null
          ? ''
          : DateFormat("yyyy-MM-dd'T'HH:mm").format(widget.quote.expiresAt!),
    );
    _items = widget.quote.items.isEmpty
        ? [_QuoteItemEditControllers.empty()]
        : widget.quote.items
            .map(_QuoteItemEditControllers.fromItem)
            .toList(growable: true);
  }

  @override
  void dispose() {
    for (final ctrl in [
      _firstName,
      _lastName,
      _phone,
      _email,
      _notes,
      _expiresAt
    ]) {
      ctrl.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(_quoteProductsProvider(null));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      maxChildSize: 0.98,
      minChildSize: 0.60,
      builder: (_, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
              'Ajustar cotización',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              widget.quote.number,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            const _SectionTitle('Cliente'),
            AppTextField(
                label: 'Nombre *',
                controller: _firstName,
                validator: _required),
            const SizedBox(height: 10),
            AppTextField(label: 'Apellido', controller: _lastName),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Teléfono *',
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: _required),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Vigencia',
                controller: _expiresAt,
                hint: '2026-06-10T18:00'),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: _SectionTitle('Items')),
                TextButton.icon(
                  onPressed: _saving ? null : _addItem,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => _EditableQuoteItemsList(
                items: _items,
                products: const [],
                saving: _saving,
                onRemove: _removeItem,
              ),
              data: (products) => _EditableQuoteItemsList(
                items: _items,
                products: products,
                saving: _saving,
                onRemove: _removeItem,
              ),
            ),
            AppTextField(label: 'Notas', controller: _notes, maxLines: 3),
            const SizedBox(height: 18),
            AppButton(
              label: 'Guardar ajuste',
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Requerido' : null;

  void _addItem() {
    setState(() => _items.add(_QuoteItemEditControllers.empty()));
  }

  void _removeItem(int index) {
    final removed = _items.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final items = _items
        .map((item) => item.toPayload())
        .whereType<Map<String, dynamic>>()
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregá al menos un item válido.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(quotesNotifierProvider.notifier)
          .updateQuote(widget.quote, {
        'customerFirstName': _firstName.text.trim(),
        'customerLastName': _emptyToNull(_lastName.text),
        'customerEmail': _emptyToNull(_email.text),
        'customerPhone': _phone.text.trim(),
        'notes': _emptyToNull(_notes.text),
        'currencyCode': widget.quote.currency,
        'expiresAt': _emptyToNull(_expiresAt.text),
        'items': items,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el ajuste.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _EditableQuoteItemsList extends StatelessWidget {
  final List<_QuoteItemEditControllers> items;
  final List<_QuoteProductOption> products;
  final bool saving;
  final ValueChanged<int> onRemove;

  const _EditableQuoteItemsList({
    required this.items,
    required this.products,
    required this.saving,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _EditableQuoteItemCard(
            item: items[index],
            products: products,
            canRemove: items.length > 1,
            onRemove: saving ? null : () => onRemove(index),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _EditableQuoteItemCard extends StatelessWidget {
  final _QuoteItemEditControllers item;
  final List<_QuoteProductOption> products;
  final bool canRemove;
  final VoidCallback? onRemove;

  const _EditableQuoteItemCard({
    required this.item,
    required this.products,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final selectedProduct = _findQuoteProductByIdentity(
      products,
      item.productId,
      item.productSku.text,
    );
    final selectedProductId = selectedProduct?.id;
    if (selectedProduct != null && selectedProduct.suggestedPrice > 0) {
      if (_parseAmount(item.suggestedPrice.text) <= 0) {
        item.suggestedPrice.text = _plainNumber(selectedProduct.suggestedPrice);
      }
      if (_parseAmount(item.unitPrice.text) <= 0) {
        item.unitPrice.text = _plainNumber(selectedProduct.suggestedPrice);
      }
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (products.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: selectedProductId,
              decoration:
                  const InputDecoration(labelText: 'Producto de catálogo'),
              items: products
                  .map((product) => DropdownMenuItem(
                        value: product.id,
                        child: Text(product.label,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (value) {
                item.productId = value;
                final selected = _findQuoteProduct(products, value);
                if (selected == null) return;
                item.productName.text = selected.name;
                item.productSku.text = selected.sku;
                item.suggestedPrice.text =
                    _plainNumber(selected.suggestedPrice);
                item.unitPrice.text = _plainNumber(selected.suggestedPrice);
                if (selected.colors.isNotEmpty &&
                    item.color.text.trim().isEmpty) {
                  item.color.text = selected.colors.first;
                }
                if (selected.presentations.isNotEmpty &&
                    item.presentation.text.trim().isEmpty) {
                  item.presentation.text = selected.presentations.first;
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          AppTextField(
              label: 'Producto *',
              controller: item.productName,
              validator: _required),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child:
                      AppTextField(label: 'SKU', controller: item.productSku)),
              const SizedBox(width: 10),
              Expanded(
                  child: AppTextField(label: 'Unidad', controller: item.unit)),
            ],
          ),
          const SizedBox(height: 10),
          AppTextField(
            label: 'Precio sugerido',
            controller: item.suggestedPrice,
            keyboardType: TextInputType.number,
            readOnly: true,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: AppTextField(
                      label: 'Cantidad *',
                      controller: item.quantity,
                      keyboardType: TextInputType.number,
                      validator: _required)),
              const SizedBox(width: 10),
              Expanded(
                  child: AppTextField(
                      label: 'Precio cotizado *',
                      controller: item.unitPrice,
                      keyboardType: TextInputType.number,
                      validator: _required)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QuoteOptionField(
                  label: 'Color',
                  controller: item.color,
                  options: selectedProduct?.colors ?? const [],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuoteOptionField(
                  label: 'Presentación',
                  controller: item.presentation,
                  options: selectedProduct?.presentations ?? const [],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: item.purchaseMode,
            decoration: const InputDecoration(labelText: 'Tipo de venta'),
            items: const [
              DropdownMenuItem(value: 'PENDING', child: Text('Pendiente')),
              DropdownMenuItem(value: 'WHOLESALE', child: Text('Por mayor')),
              DropdownMenuItem(value: 'RETAIL', child: Text('Por menor')),
            ],
            onChanged: (value) => item.purchaseMode = value ?? 'PENDING',
          ),
          if (canRemove) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Quitar'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Requerido' : null;
}

class _QuoteOptionField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;

  const _QuoteOptionField({
    required this.label,
    required this.controller,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final cleanOptions = options
        .map((option) => option.trim().toUpperCase())
        .where((option) => option.isNotEmpty)
        .toSet()
        .toList();
    if (cleanOptions.isEmpty) {
      return AppTextField(label: label, controller: controller);
    }

    final current = controller.text.trim().toUpperCase();
    final value = cleanOptions.contains(current) ? current : null;
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: cleanOptions
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: (next) => controller.text = next ?? '',
    );
  }
}

class _QuoteItemEditControllers {
  String? productId;
  final TextEditingController productName;
  final TextEditingController productSku;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController suggestedPrice;
  final TextEditingController unitPrice;
  final TextEditingController color;
  final TextEditingController presentation;
  String purchaseMode;

  _QuoteItemEditControllers({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.unit,
    required this.suggestedPrice,
    required this.unitPrice,
    required this.color,
    required this.presentation,
    required this.purchaseMode,
  });

  factory _QuoteItemEditControllers.empty() => _QuoteItemEditControllers(
        productId: null,
        productName: TextEditingController(),
        productSku: TextEditingController(),
        quantity: TextEditingController(text: '1'),
        unit: TextEditingController(text: 'U'),
        suggestedPrice: TextEditingController(text: '0'),
        unitPrice: TextEditingController(text: '0'),
        color: TextEditingController(),
        presentation: TextEditingController(),
        purchaseMode: 'PENDING',
      );

  factory _QuoteItemEditControllers.fromItem(QuoteItemDto item) =>
      _QuoteItemEditControllers(
        productId: item.productId,
        productName: TextEditingController(text: item.productName),
        productSku: TextEditingController(text: item.productSku ?? ''),
        quantity: TextEditingController(text: _qty(item.quantity)),
        unit: TextEditingController(text: item.unit),
        suggestedPrice:
            TextEditingController(text: _plainNumber(item.unitPrice)),
        unitPrice: TextEditingController(text: _plainNumber(item.unitPrice)),
        color: TextEditingController(text: item.color ?? ''),
        presentation: TextEditingController(text: item.presentation ?? ''),
        purchaseMode: item.purchaseMode ?? 'PENDING',
      );

  Map<String, dynamic>? toPayload() {
    final name = productName.text.trim();
    final qty = _parseAmount(quantity.text);
    if (name.isEmpty || qty <= 0) return null;
    final sku = productSku.text.trim();
    return {
      'productId': productId ?? (sku.isNotEmpty ? sku : 'MOBILE-MANUAL'),
      'productSku': sku,
      'productName': name,
      'color': _upperOrNull(color.text),
      'presentation': _upperOrNull(presentation.text),
      'purchaseMode': purchaseMode,
      'quantity': qty,
      'unit': _upperOrDefault(unit.text, 'U'),
      'unitPrice': _parseAmount(unitPrice.text),
    };
  }

  void dispose() {
    for (final ctrl in [
      productName,
      productSku,
      quantity,
      unit,
      suggestedPrice,
      unitPrice,
      color,
      presentation
    ]) {
      ctrl.dispose();
    }
  }
}

class _CustomerPanel extends StatelessWidget {
  final QuoteDto quote;

  const _CustomerPanel({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.person_rounded,
            label: 'Cliente',
            value: quote.customerName,
          ),
          if (quote.customerPhone != null)
            _InfoRow(
              icon: Icons.phone_rounded,
              label: 'Teléfono',
              value: quote.customerPhone!,
            ),
          if (quote.customerEmail != null)
            _InfoRow(
              icon: Icons.mail_rounded,
              label: 'Email',
              value: quote.customerEmail!,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.ink, fontSize: 12.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteItemCard extends StatelessWidget {
  final QuoteItemDto item;
  final String currency;

  const _QuoteItemCard({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.productName,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                _money(item.lineTotal, currency),
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (item.productSku != null) ...[
            const SizedBox(height: 2),
            Text(
              item.productSku!,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill('Color', item.color ?? '-'),
              _Pill('Presentación', item.presentation ?? '-'),
              _Pill('Cantidad', '${_qty(item.quantity)} ${item.unit}'),
              _Pill('Modo', _purchaseModeLabel(item.purchaseMode)),
              _Pill('Unitario', _money(item.unitPrice, currency)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;

  const _Pill(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuoteDeliveryActions extends StatelessWidget {
  final QuoteDto quote;

  const _QuoteDeliveryActions({required this.quote});

  @override
  Widget build(BuildContext context) {
    final emailEnabled = quote.customerEmail != null;
    final whatsappEnabled =
        _normalizeWhatsappPhone(quote.customerPhone).isNotEmpty;
    final pdfEnabled = quote.pdfUrl != null;
    final isDraft = quote.status == 'DRAFT';
    final invalidPrice = _quoteHasInvalidQuotedPrice(quote);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDraft ? 'Contactar cliente' : 'Enviar cotización',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDraft
                ? 'En borrador se abre un mensaje simple para resolver dudas con el cliente.'
                : 'Acciones habilitadas porque la cotización está enviada.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (!isDraft) ...[
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: 'PDF',
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: () => _openPdf(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Email',
                    icon: Icons.mail_outline_rounded,
                    onPressed: emailEnabled && !invalidPrice
                        ? () => _openEmail(context)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          AppButton(
            label: isDraft ? 'Contactar' : 'WhatsApp',
            icon: Icons.chat_bubble_outline_rounded,
            fullWidth: true,
            onPressed: whatsappEnabled ? () => _openWhatsapp(context) : null,
          ),
          if (!isDraft &&
              (!emailEnabled ||
                  !whatsappEnabled ||
                  !pdfEnabled ||
                  invalidPrice)) ...[
            const SizedBox(height: 8),
            Text(
              _missingText(
                  emailEnabled, whatsappEnabled, pdfEnabled, invalidPrice),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPdf(BuildContext context) async {
    if (_quoteHasInvalidQuotedPrice(quote)) {
      _showSnack(
          context, 'Cargá precio cotizado mayor a 0 en todos los productos.');
      return;
    }
    final url = quote.pdfUrl;
    if (url == null) {
      _showSnack(context, 'El PDF todavía no fue generado por backend.');
      return;
    }
    await _launchExternal(context, Uri.parse(url), 'No se pudo abrir el PDF.');
  }

  Future<void> _openEmail(BuildContext context) async {
    if (_quoteHasInvalidQuotedPrice(quote)) {
      _showSnack(
          context, 'Cargá precio cotizado mayor a 0 en todos los productos.');
      return;
    }
    final email = quote.customerEmail;
    if (email == null) return;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Cotización ${quote.number}',
        'body': _quoteShareText(quote),
      },
    );
    await _launchExternal(context, uri, 'No se pudo abrir el email.');
  }

  Future<void> _openWhatsapp(BuildContext context) async {
    final phone = _normalizeWhatsappPhone(quote.customerPhone);
    if (phone.isEmpty) return;
    final uri = Uri.parse(
      'https://api.whatsapp.com/send/?phone=$phone&text=${Uri.encodeComponent(_quoteWhatsappText(quote))}&type=phone_number&app_absent=0',
    );
    await _launchExternal(context, uri, 'No se pudo abrir WhatsApp.');
  }

  String _missingText(bool email, bool whatsapp, bool pdf, bool invalidPrice) {
    final missing = <String>[
      if (invalidPrice) 'precio cotizado pendiente',
      if (!pdf) 'PDF pendiente',
      if (!email) 'sin email',
      if (!whatsapp) 'sin teléfono',
    ];
    return missing.join(' · ');
  }
}

bool _quoteHasInvalidQuotedPrice(QuoteDto quote) =>
    quote.items.any((item) => item.unitPrice <= 0);

class _PublicQrPanel extends StatelessWidget {
  final String url;

  const _PublicQrPanel({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 94,
            height: 94,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(data: url),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aprobar online',
                  style: TextStyle(
                    color: AppColors.accentDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'QR habilitado porque la cotización está enviada.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar link'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedLinkPanel extends StatelessWidget {
  final String status;

  const _LockedLinkPanel({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'El link público y QR se habilitan cuando la cotización está enviada.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  final String notes;

  const _NotesPanel({required this.notes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        notes,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'DRAFT':
      return 'Borrador';
    case 'SENT':
      return 'Enviada';
    case 'ANSWERED':
      return 'A revisar';
    case 'WON':
      return 'Ganada';
    case 'LOST':
      return 'Perdida';
    case 'EXPIRED':
      return 'Vencida';
    default:
      return status;
  }
}

String _purchaseModeLabel(String? value) {
  switch (value) {
    case 'WHOLESALE':
      return 'Por mayor';
    case 'RETAIL':
      return 'Por menor';
    case 'PENDING':
      return 'Pendiente';
    default:
      return value ?? '-';
  }
}

String _formatDate(DateTime date) =>
    DateFormat('dd/MM/yyyy HH:mm').format(date);

_QuoteProductOption? _findQuoteProduct(
  List<_QuoteProductOption> products,
  String? productId,
) {
  if (productId == null || productId.trim().isEmpty) return null;
  for (final product in products) {
    if (product.id == productId) return product;
  }
  return null;
}

_QuoteProductOption? _findQuoteProductByIdentity(
  List<_QuoteProductOption> products,
  String? productId,
  String? sku,
) {
  final refs = {
    if (productId != null && productId.trim().isNotEmpty) productId.trim(),
    if (sku != null && sku.trim().isNotEmpty) sku.trim(),
  };
  if (refs.isEmpty) return null;
  for (final product in products) {
    if (refs.contains(product.id) || refs.contains(product.sku)) return product;
  }
  return null;
}

double _parseAnyAmount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is Map) {
    return _parseAnyAmount(value['amount'] ?? value['value'] ?? value['price']);
  }
  return double.tryParse(value.toString().trim().replaceAll(',', '.')) ?? 0;
}

double _parseFirstAmount(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final parsed = _parseAnyAmount(json[key]);
    if (parsed > 0) return parsed;
  }
  return 0;
}

String? _emptyToNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String? _upperOrNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text.toUpperCase();
}

String _upperOrDefault(String value, String fallback) {
  final text = value.trim();
  return text.isEmpty ? fallback : text.toUpperCase();
}

double _parseAmount(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;

String _plainNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _phoneDigits(String? value) =>
    (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');

String _normalizeWhatsappPhone(String? value,
    {String defaultCountryCode = '54'}) {
  var digits = _phoneDigits(value);
  if (digits.isEmpty) return '';
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith(defaultCountryCode)) return digits;
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  return '$defaultCountryCode$digits';
}

String _quoteDraftContactText(QuoteDto quote) =>
    'Hola, quería contactarte por la cotización que nos hiciste con el comprobante ${quote.number}.';

String _quoteWhatsappText(QuoteDto quote) => quote.status == 'DRAFT'
    ? _quoteDraftContactText(quote)
    : _quoteShareText(quote);

String _quoteShareText(QuoteDto quote) {
  final lines = <String>[
    'Hola ${quote.customerName}, te enviamos la cotización ${quote.number}.',
    'Total: ${_money(quote.total, quote.currency)}.',
    if (quote.hasPublicLink)
      'Podés aprobarla o solicitar ajuste acá: ${quote.publicUrl}',
  ];
  return lines.join('\n');
}

Future<void> _launchExternal(
  BuildContext context,
  Uri uri,
  String errorMessage,
) async {
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) _showSnack(context, errorMessage);
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _money(double value, String currency) {
  final format = NumberFormat.currency(
    locale: 'es_AR',
    symbol: currency == 'ARS' ? r'$' : '$currency ',
    decimalDigits: 2,
  );
  return format.format(value);
}

String _qty(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
