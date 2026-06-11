import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/image_upload_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

class _TenantLookupDto {
  final String id;
  final String name;

  const _TenantLookupDto({required this.id, required this.name});

  factory _TenantLookupDto.fromJson(Map<String, dynamic> json) => _TenantLookupDto(
        id: (json['tenantId'] ?? json['companyId'] ?? json['id'])?.toString() ?? '',
        name: (json['name'] ?? json['tenantName'] ?? json['companyName'] ?? json['code'] ?? 'Empresa').toString(),
      );
}

class _SellerLookupDto {
  final String id;
  final String name;
  final String? tenantId;

  const _SellerLookupDto({required this.id, required this.name, this.tenantId});

  factory _SellerLookupDto.fromJson(Map<String, dynamic> json) => _SellerLookupDto(
        id: (json['sellerId'] ?? json['id'])?.toString() ?? '',
        name: (json['name'] ?? json['sellerName'] ?? json['businessName'] ?? json['sellerCode'] ?? 'Seller').toString(),
        tenantId: (json['tenantId'] ?? json['companyId'])?.toString(),
      );
}

final _tenantsLookupProvider = FutureProvider.autoDispose<List<_TenantLookupDto>>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get(
      '/v1/tenants',
      queryParameters: const {
        'page': 0,
        'size': 200,
        'pageSize': 200,
      },
    );
    return PaginatedResponse.fromJson(resp.data, _TenantLookupDto.fromJson).items;
  },
);

final _sellersLookupProvider = FutureProvider.autoDispose
    .family<List<_SellerLookupDto>, String?>((ref, tenantId) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(
    '/v1/sellers',
    queryParameters: {
      'page': 0,
      'size': 200,
      'pageSize': 200,
      if (tenantId != null && tenantId.trim().isNotEmpty) 'tenantId': tenantId.trim(),
    },
  );
  final items = PaginatedResponse.fromJson(resp.data, _SellerLookupDto.fromJson).items;
  final scope = tenantId?.trim();
  if (scope == null || scope.isEmpty) return items;
  return items.where((s) => s.tenantId == null || s.tenantId == scope).toList();
});

class _CatalogLookupDto {
  final String code;
  final String name;

  const _CatalogLookupDto({required this.code, required this.name});

  factory _CatalogLookupDto.fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ??
            json['currencyCode'] ??
            json['statusCode'] ??
            json['typeCode'] ??
            json['id'] ??
            json['typeId'])
        ?.toString() ??
        '';
    final name = (json['name'] ??
            json['currencyName'] ??
            json['description'] ??
            json['label'] ??
            code)
        .toString();
    return _CatalogLookupDto(code: code, name: name);
  }
}

class _CatalogDropdownField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final AsyncValue<List<_CatalogLookupDto>> options;
  final String? fallbackHint;
  final String? Function(String?)? validator;

  const _CatalogDropdownField({
    required this.label,
    required this.controller,
    required this.options,
    this.fallbackHint,
    this.validator,
  });

  @override
  State<_CatalogDropdownField> createState() => _CatalogDropdownFieldState();
}

class _CatalogDropdownFieldState extends State<_CatalogDropdownField> {
  @override
  Widget build(BuildContext context) {
    return widget.options.when(
      loading: () => AppTextField(
        label: widget.label,
        hint: 'Cargando...',
        controller: widget.controller,
        validator: widget.validator,
      ),
      error: (_, __) => AppTextField(
        label: widget.label,
        hint: widget.fallbackHint,
        controller: widget.controller,
        validator: widget.validator,
      ),
      data: (options) {
        if (options.isEmpty) {
          return AppTextField(
            label: widget.label,
            hint: widget.fallbackHint,
            controller: widget.controller,
            validator: widget.validator,
          );
        }

        final current = widget.controller.text.trim();
        final values = options.map((option) => option.code).toSet();
        final value = values.contains(current) ? current : null;

        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(labelText: widget.label),
          validator: widget.validator,
          items: options
              .map(
                (option) => DropdownMenuItem(
                  value: option.code,
                  child: Text(
                    option.name == option.code
                        ? option.code
                        : '${option.name} (${option.code})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (next) {
            widget.controller.text = next ?? '';
            setState(() {});
          },
        );
      },
    );
  }
}

final _catalogLookupProvider = FutureProvider.autoDispose
    .family<List<_CatalogLookupDto>, String>((ref, path) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(
    path,
    queryParameters: const {'page': 0, 'size': 200, 'pageSize': 200},
  );
  return PaginatedResponse.fromJson(resp.data, _CatalogLookupDto.fromJson)
      .items
      .where((item) => item.code.trim().isNotEmpty)
      .toList();
});

// ─── State ───────────────────────────────────────────────────────────────────

class _ProductFormState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final Map<String, String?> fields;

  const _ProductFormState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.fields = const {},
  });

  _ProductFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    Map<String, String?>? fields,
  }) =>
      _ProductFormState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: error,
        fields: fields ?? this.fields,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ProductFormNotifier extends StateNotifier<_ProductFormState> {
  final Dio _dio;
  final String? productId;

  ProductFormNotifier(this._dio, this.productId)
      : super(const _ProductFormState()) {
    if (productId != null) _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final resp = await _dio.get('/v1/products/$productId');
      final data = _extractProductPayload(resp.data);
      final fields = {
        'name': _readString(data, const ['name', 'productName']),
        'slug': _readString(data, const ['slug']),
        'sku': _readString(data, const ['sku', 'productSku']),
        'companyId': _readString(data, const ['companyId', 'tenantId']),
        'sellerId': _readString(data, const ['sellerId']),
        'priceTypeCode':
            _readString(data, const ['priceTypeCode', 'priceType']) ?? 'FIXED',
        'basePrice': _readString(data, const ['basePrice', 'price', 'retailPrice']),
        'currencyCode': _readString(data, const ['currencyCode', 'currency']) ?? 'ARS',
        'statusCode': _readString(data, const ['statusCode', 'status']) ?? 'DRAFT',
        'stockStatusCode': _readString(data, const ['stockStatusCode', 'stockStatus']),
        'productTypeCode':
            _readString(data, const ['productTypeCode', 'typeCode', 'productType']),
        'featured': _readString(data, const ['featured']),
        'description': _readString(data, const ['description']),
        'category': _readString(data, const ['category', 'categoryName']),
        'tags': (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).join(', '),
        'uses': (data['uses'] as List<dynamic>?)?.map((e) => e.toString()).join(', '),
        'discountPercent': _readString(data, const ['discountPercent', 'discount']),
        ..._readProductImageFields(data),
      };
      fields.addAll(await _loadProductImageFields());
      state = state.copyWith(
        isLoading: false,
        fields: fields,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: ErrorHandler.handle(e).message);
    }
  }

  Future<Map<String, String?>> _loadProductImageFields() async {
    try {
      final resp = await _dio.get('/v1/products/$productId/images');
      return _readProductImageFields({'images': _extractListPayload(resp.data)});
    } catch (_) {
      return const <String, String?>{};
    }
  }

  Future<String?> save({
    required String name,
    required String slug,
    required String companyId,
    required String sellerId,
    required String priceTypeCode,
    required String currencyCode,
    required String statusCode,
    String? sku,
    String? description,
    String? category,
    String? basePrice,
    String? stockStatusCode,
    String? productTypeCode,
    String? tags,
    String? uses,
    String? discountPercent,
    required bool featured,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final body = {
        'name': name,
        'slug': slug,
        'companyId': companyId,
        'sellerId': sellerId,
        'priceTypeCode': priceTypeCode,
        'currencyCode': currencyCode,
        'statusCode': statusCode,
        'featured': featured,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
        if (stockStatusCode != null && stockStatusCode.isNotEmpty)
          'stockStatusCode': stockStatusCode,
        if (productTypeCode != null && productTypeCode.isNotEmpty)
          'productTypeCode': productTypeCode,
        if (tags != null && tags.isNotEmpty) 'tags': _splitCsv(tags),
        if (uses != null && uses.isNotEmpty) 'uses': _splitCsv(uses),
        if (basePrice != null && basePrice.isNotEmpty)
          'basePrice': double.tryParse(basePrice),
        if (discountPercent != null && discountPercent.isNotEmpty)
          'discountPercent': double.tryParse(discountPercent),
      };
      if (productId == null) {
        final resp = await _dio.post('/v1/products', data: body);
        final data = resp.data;
        state = state.copyWith(isSaving: false);
        if (data is Map) {
          return (data['productId'] ?? data['id'])?.toString();
        }
        return null;
      } else {
        await _dio.put('/v1/products/$productId', data: body);
      }
      state = state.copyWith(isSaving: false);
      return productId;
    } catch (e) {
      state = state.copyWith(
          isSaving: false, error: ErrorHandler.handle(e).message);
      return null;
    }
  }

  Future<void> uploadImage({
    required String productId,
    required String companyId,
    required XFile file,
    required int sortOrder,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    await _dio.post(
      '/v1/products/$productId/images/upload',
      queryParameters: {
        'companyId': companyId,
        'sortOrder': sortOrder,
      },
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  List<String> _splitCsv(String raw) => raw
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();
}

Map<String, dynamic> _extractProductPayload(dynamic raw) {
  if (raw is! Map) return <String, dynamic>{};
  final map = Map<String, dynamic>.from(raw);
  for (final key in const ['data', 'product', 'item']) {
    final nested = map[key];
    if (nested is Map) return Map<String, dynamic>.from(nested);
  }
  return map;
}

List<dynamic> _extractListPayload(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    for (final key in const ['content', 'items', 'data', 'images', 'results']) {
      final value = raw[key];
      if (value is List) return value;
      if (value is Map) {
        final nested = _extractListPayload(value);
        if (nested.isNotEmpty) return nested;
      }
    }
  }
  return const [];
}

String? _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    if (value is Map) {
      final nested = _readString(Map<String, dynamic>.from(value), const [
        'id',
        'code',
        'name',
        'value',
      ]);
      if (nested != null && nested.trim().isNotEmpty) return nested;
      continue;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

Map<String, String?> _readProductImageFields(Map<String, dynamic> data) {
  final urls = <String>[];

  void addUrl(dynamic value) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty && text != 'null') {
      urls.add(text);
    }
  }

  addUrl(data['imageUrl']);
  addUrl(data['mainImageUrl']);
  addUrl(data['coverImageUrl']);
  addUrl(data['url']);
  addUrl(data['cardUrl']);
  addUrl(data['thumbUrl']);
  addUrl(data['detailUrl']);
  addUrl(data['masterUrl']);

  for (final key in const ['images', 'gallery', 'productImages']) {
    final value = data[key];
    if (value is! List) continue;
    final sorted = [...value];
    sorted.sort((a, b) {
      int orderOf(dynamic item) {
        if (item is Map) {
          final raw = item['sortOrder'] ?? item['order'] ?? item['position'];
          if (raw is num) return raw.toInt();
          return int.tryParse(raw?.toString() ?? '') ?? 999;
        }
        return 999;
      }

      return orderOf(a).compareTo(orderOf(b));
    });
    for (final item in sorted) {
      if (item is Map) {
        addUrl(item['imageUrl'] ??
            item['url'] ??
            item['cardUrl'] ??
            item['thumbUrl'] ??
            item['detailUrl'] ??
            item['masterUrl'] ??
            item['mediaUrl'] ??
            item['fileUrl'] ??
            item['publicUrl'] ??
            item['path']);
      } else {
        addUrl(item);
      }
    }
  }

  final unique = <String>[];
  for (final url in urls) {
    if (!unique.contains(url)) unique.add(url);
  }
  return {
    for (var i = 0; i < unique.length && i < 5; i++) 'imageUrl$i': unique[i],
  };
}

final productFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<ProductFormNotifier, _ProductFormState, String?>(
  (ref, id) => ProductFormNotifier(ref.watch(dioProvider), id),
);

// ─── Screen ──────────────────────────────────────────────────────────────────

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _slugCtrl;
  late final TextEditingController _skuCtrl;
  late final TextEditingController _priceTypeCtrl;
  late final TextEditingController _basePriceCtrl;
  late final TextEditingController _discountPercentCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _stockStatusCtrl;
  late final TextEditingController _productTypeCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _usesCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _categoryCtrl;

  bool _didHydrateFromServer = false;
  String? _selectedCompanyId;
  String? _selectedSellerId;
  String _statusCode = 'DRAFT';
  bool _featured = false;
  final List<XFile?> _imageFiles = List<XFile?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _slugCtrl = TextEditingController();
    _skuCtrl = TextEditingController();
    _priceTypeCtrl = TextEditingController(text: 'FIXED');
    _basePriceCtrl = TextEditingController();
    _discountPercentCtrl = TextEditingController();
    _currencyCtrl = TextEditingController(text: 'ARS');
    _stockStatusCtrl = TextEditingController();
    _productTypeCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
    _usesCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _categoryCtrl = TextEditingController();

    final auth = ref.read(authNotifierProvider);
    if (!auth.isAdminGlobal && auth.tenantId != null && auth.tenantId!.trim().isNotEmpty) {
      _selectedCompanyId = auth.tenantId;
    }
    if (!auth.isAdminGlobal) {
      final scopedSeller = auth.sellerId ?? (auth.sellerIds.length == 1 ? auth.sellerIds.first : null);
      if (scopedSeller != null && scopedSeller.trim().isNotEmpty) {
        _selectedSellerId = scopedSeller.trim();
      }
    }

    ref.listen<_ProductFormState>(
      productFormNotifierProvider(widget.productId),
      (prev, next) {
        _hydrateFromServer(next.fields);
      },
    );
  }

  void _hydrateFromServer(Map<String, String?> fields) {
    if (_didHydrateFromServer || fields.isEmpty) return;
    _didHydrateFromServer = true;

    _nameCtrl.text = fields['name'] ?? '';
    _slugCtrl.text = fields['slug'] ?? '';
    _skuCtrl.text = fields['sku'] ?? '';
    _priceTypeCtrl.text = fields['priceTypeCode'] ?? 'FIXED';
    _basePriceCtrl.text = fields['basePrice'] ?? '';
    _discountPercentCtrl.text = fields['discountPercent'] ?? '';
    _currencyCtrl.text = fields['currencyCode'] ?? 'ARS';
    _stockStatusCtrl.text = fields['stockStatusCode'] ?? '';
    _productTypeCtrl.text = fields['productTypeCode'] ?? '';
    _tagsCtrl.text = fields['tags'] ?? '';
    _usesCtrl.text = fields['uses'] ?? '';
    _descriptionCtrl.text = fields['description'] ?? '';
    _categoryCtrl.text = fields['category'] ?? '';
    _statusCode = fields['statusCode'] ?? 'DRAFT';
    _featured = fields['featured'] == 'true';

    final companyId = fields['companyId'];
    final sellerId = fields['sellerId'];
    if (mounted) {
      setState(() {
        if ((_selectedCompanyId == null || _selectedCompanyId!.trim().isEmpty) &&
            companyId != null &&
            companyId.trim().isNotEmpty) {
          _selectedCompanyId = companyId.trim();
        }
        if (sellerId != null && sellerId.trim().isNotEmpty) {
          _selectedSellerId = sellerId.trim();
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _slugCtrl, _skuCtrl,
      _priceTypeCtrl, _basePriceCtrl, _discountPercentCtrl, _currencyCtrl, _stockStatusCtrl,
      _productTypeCtrl,
      _tagsCtrl, _usesCtrl, _descriptionCtrl, _categoryCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authNotifierProvider);
    final companyId = auth.isAdminGlobal
        ? (_selectedCompanyId?.trim())
        : (auth.tenantId?.trim());

    if (companyId == null || companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná una empresa para continuar.')),
      );
      return;
    }
    final sellerId = _selectedSellerId?.trim();
    if (sellerId == null || sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleccioná un seller para continuar.')),
      );
      return;
    }

    final notifier =
        ref.read(productFormNotifierProvider(widget.productId).notifier);
    final savedProductId = await notifier.save(
      name: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      companyId: companyId,
      sellerId: sellerId,
      priceTypeCode: _priceTypeCtrl.text.trim(),
      currencyCode: _currencyCtrl.text.trim().isEmpty ? 'ARS' : _currencyCtrl.text.trim().toUpperCase(),
      statusCode: _statusCode,
      sku: _skuCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      basePrice: _basePriceCtrl.text.trim(),
      discountPercent: _discountPercentCtrl.text.trim(),
      stockStatusCode: _stockStatusCtrl.text.trim().toUpperCase(),
      productTypeCode: _productTypeCtrl.text.trim().toUpperCase(),
      tags: _tagsCtrl.text.trim(),
      uses: _usesCtrl.text.trim(),
      featured: _featured,
    );
    if (savedProductId == null) return;

    final selectedUploads = _imageFiles
        .asMap()
        .entries
        .where((entry) => entry.value != null)
        .toList();
    if (selectedUploads.isNotEmpty) {
      var failed = 0;
      for (final entry in selectedUploads) {
        try {
          await notifier.uploadImage(
            productId: savedProductId,
            companyId: companyId,
            file: entry.value!,
            sortOrder: entry.key,
          );
        } catch (_) {
          failed++;
        }
      }
      if (failed > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$failed imagen(es) no se pudieron subir.')),
        );
      }
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormNotifierProvider(widget.productId));
    if (!_didHydrateFromServer && state.fields.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrateFromServer(state.fields);
      });
    }
    final isEdit = widget.productId != null;
    final auth = ref.watch(authNotifierProvider);
    final tenantsAsync = auth.isAdminGlobal ? ref.watch(_tenantsLookupProvider) : null;
    final companyForSellers = auth.isAdminGlobal ? _selectedCompanyId : auth.tenantId;
    final sellersAsync = ref.watch(_sellersLookupProvider(companyForSellers));
    final priceTypesAsync = ref.watch(_catalogLookupProvider('/v1/price-types'));
    final currenciesAsync = ref.watch(_catalogLookupProvider('/v1/currencies'));
    final stockStatusesAsync = ref.watch(_catalogLookupProvider('/v1/stock-statuses'));
    final productTypesAsync = ref.watch(_catalogLookupProvider('/v1/product-types'));
    final lockSeller = !auth.isAdminGlobal && auth.sellerScope == 'SINGLE';

    return AppPageScaffold(
      title: isEdit ? 'Editar producto' : 'Nuevo producto',
      body: state.isLoading
          ? const LoadingState()
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.error != null)
                      ErrorState(
                        message: state.error!,
                        onRetry: null,
                      ),
                    AppTextField(
                      label: 'Nombre *',
                      controller: _nameCtrl,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Slug *',
                      hint: 'ej: mi-producto-v2',
                      controller: _slugCtrl,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    if (auth.isAdminGlobal) ...[
                      tenantsAsync!.when(
                        loading: () => const SizedBox(
                          height: 56,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Cargando empresas…'),
                          ),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (tenants) {
                          if (tenants.isEmpty) return const SizedBox.shrink();
                          return DropdownButtonFormField<String>(
                            key: ValueKey(_selectedCompanyId ?? 'none'),
                            initialValue: _selectedCompanyId,
                            decoration: const InputDecoration(
                              labelText: 'Empresa *',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                            items: tenants
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text(
                                      t.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedCompanyId = v;
                              _selectedSellerId = null;
                            }),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    sellersAsync.when(
                      loading: () => const SizedBox(
                        height: 56,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Cargando sellers…'),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (sellers) {
                        final allowedSellerIds = {
                          if (auth.sellerId != null && auth.sellerId!.trim().isNotEmpty) auth.sellerId!.trim(),
                          ...auth.sellerIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
                        };
                        final visibleSellers = auth.isAdminGlobal || allowedSellerIds.isEmpty
                            ? sellers
                            : sellers.where((seller) => allowedSellerIds.contains(seller.id)).toList();
                        if (visibleSellers.isEmpty) return const SizedBox.shrink();
                        if (_selectedSellerId != null &&
                            !visibleSellers.any((seller) => seller.id == _selectedSellerId)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _selectedSellerId = null);
                          });
                        }
                        if (_selectedSellerId == null &&
                            (visibleSellers.length == 1 || lockSeller)) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _selectedSellerId == null) {
                              setState(() => _selectedSellerId = visibleSellers.first.id);
                            }
                          });
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey(_selectedSellerId ?? 'seller-none'),
                          initialValue: _selectedSellerId,
                          decoration: const InputDecoration(labelText: 'Seller *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          items: visibleSellers
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: lockSeller ? null : (v) => setState(() => _selectedSellerId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _statusCode,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: const [
                        DropdownMenuItem(value: 'DRAFT', child: Text('Borrador')),
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Activo')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactivo')),
                      ],
                      onChanged: (v) => setState(() => _statusCode = v ?? 'DRAFT'),
                    ),
                    const SizedBox(height: 12),
                    _CatalogDropdownField(
                      label: 'Tipo de precio *',
                      controller: _priceTypeCtrl,
                      options: priceTypesAsync,
                      fallbackHint: 'FIXED / CONSULT',
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'SKU',
                      controller: _skuCtrl,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Precio base',
                      controller: _basePriceCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v != null && v.isNotEmpty) {
                          if (double.tryParse(v) == null) {
                            return 'Ingresá un número válido';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: '% descuento',
                      controller: _discountPercentCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final parsed = double.tryParse(v.trim());
                        if (parsed == null) return 'Ingresá un número válido';
                        if (parsed < 0 || parsed > 100) return 'Debe estar entre 0 y 100';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _CatalogDropdownField(
                      label: 'Moneda',
                      controller: _currencyCtrl,
                      options: currenciesAsync,
                      fallbackHint: 'ARS',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Categoría',
                      controller: _categoryCtrl,
                    ),
                    const SizedBox(height: 12),
                    _CatalogDropdownField(
                      label: 'Estado de stock',
                      controller: _stockStatusCtrl,
                      options: stockStatusesAsync,
                      fallbackHint: 'IN_STOCK / OUT_OF_STOCK',
                    ),
                    const SizedBox(height: 12),
                    _CatalogDropdownField(
                      label: 'Tipo de producto',
                      controller: _productTypeCtrl,
                      options: productTypesAsync,
                      fallbackHint: 'GENERIC',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Tags',
                      hint: 'Separados por coma',
                      controller: _tagsCtrl,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Usos',
                      hint: 'Separados por coma',
                      controller: _usesCtrl,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: _featured,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Producto destacado'),
                      onChanged: (value) => setState(() => _featured = value),
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      label: 'Descripción',
                      controller: _descriptionCtrl,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Imágenes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(5, (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ImageUploadField(
                            label: index == 0
                                ? 'Portada / imagen principal'
                                : 'Imagen secundaria ${index + 1}',
                            imageUrl: state.fields['imageUrl$index'],
                            height: index == 0 ? 180 : 132,
                            onChanged: (file) => setState(() => _imageFiles[index] = file),
                          ),
                        )),
                    const SizedBox(height: 24),
                    AppButton(
                      label: isEdit ? 'Guardar cambios' : 'Crear producto',
                      isLoading: state.isSaving,
                      onPressed: _save,
                      fullWidth: true,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
