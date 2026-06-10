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
        id: (json['id'])?.toString() ?? '',
        name: (json['name'])?.toString() ?? '',
      );
}

class _SellerLookupDto {
  final String id;
  final String name;
  final String? tenantId;

  const _SellerLookupDto({required this.id, required this.name, this.tenantId});

  factory _SellerLookupDto.fromJson(Map<String, dynamic> json) => _SellerLookupDto(
        id: (json['sellerId'] ?? json['id'])?.toString() ?? '',
        name: (json['name'] ?? json['sellerCode'] ?? 'Seller').toString(),
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
    queryParameters: const {'page': 0, 'size': 200, 'pageSize': 200},
  );
  final items = PaginatedResponse.fromJson(resp.data, _SellerLookupDto.fromJson).items;
  final scope = tenantId?.trim();
  if (scope == null || scope.isEmpty) return items;
  return items.where((s) => s.tenantId == null || s.tenantId == scope).toList();
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
      final data = resp.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        fields: {
          'name': data['name']?.toString(),
          'slug': data['slug']?.toString(),
          'sku': data['sku']?.toString(),
          'companyId': data['companyId']?.toString(),
          'sellerId': data['sellerId']?.toString(),
          'priceTypeCode': data['priceTypeCode']?.toString() ?? 'FIXED',
          'basePrice': data['basePrice']?.toString(),
          'currencyCode': data['currencyCode']?.toString() ?? 'ARS',
          'statusCode': data['statusCode']?.toString() ?? 'DRAFT',
          'stockStatusCode': data['stockStatusCode']?.toString(),
          'featured': data['featured']?.toString(),
          'description': data['description']?.toString(),
          'category': data['category']?.toString(),
          'tags': (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).join(', '),
          'uses': (data['uses'] as List<dynamic>?)?.map((e) => e.toString()).join(', '),
          'netWeight': data['netWeight']?.toString(),
          'grossWeight': data['grossWeight']?.toString(),
          'volume': data['volume']?.toString(),
          'height': data['height']?.toString(),
          'width': data['width']?.toString(),
          'length': data['length']?.toString(),
        },
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: ErrorHandler.handle(e).message);
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
    String? tags,
    String? uses,
    String? netWeight,
    String? grossWeight,
    String? volume,
    String? height,
    String? width,
    String? length,
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
        if (tags != null && tags.isNotEmpty) 'tags': _splitCsv(tags),
        if (uses != null && uses.isNotEmpty) 'uses': _splitCsv(uses),
        if (basePrice != null && basePrice.isNotEmpty)
          'basePrice': double.tryParse(basePrice),
        if (netWeight != null && netWeight.isNotEmpty)
          'netWeight': double.tryParse(netWeight),
        if (grossWeight != null && grossWeight.isNotEmpty)
          'grossWeight': double.tryParse(grossWeight),
        if (volume != null && volume.isNotEmpty)
          'volume': double.tryParse(volume),
        if (height != null && height.isNotEmpty)
          'height': double.tryParse(height),
        if (width != null && width.isNotEmpty)
          'width': double.tryParse(width),
        if (length != null && length.isNotEmpty)
          'length': double.tryParse(length),
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
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _stockStatusCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _usesCtrl;
  late final TextEditingController _netWeightCtrl;
  late final TextEditingController _grossWeightCtrl;
  late final TextEditingController _volumeCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _widthCtrl;
  late final TextEditingController _lengthCtrl;
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
    _currencyCtrl = TextEditingController(text: 'ARS');
    _stockStatusCtrl = TextEditingController();
    _tagsCtrl = TextEditingController();
    _usesCtrl = TextEditingController();
    _netWeightCtrl = TextEditingController();
    _grossWeightCtrl = TextEditingController();
    _volumeCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _widthCtrl = TextEditingController();
    _lengthCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _categoryCtrl = TextEditingController();

    final auth = ref.read(authNotifierProvider);
    if (!auth.isAdminGlobal && auth.tenantId != null && auth.tenantId!.trim().isNotEmpty) {
      _selectedCompanyId = auth.tenantId;
    }

    ref.listen<_ProductFormState>(
      productFormNotifierProvider(widget.productId),
      (prev, next) {
        if (_didHydrateFromServer) return;
        if (next.fields.isEmpty) return;
        _didHydrateFromServer = true;

        _nameCtrl.text = next.fields['name'] ?? '';
        _slugCtrl.text = next.fields['slug'] ?? '';
        _skuCtrl.text = next.fields['sku'] ?? '';
        _priceTypeCtrl.text = next.fields['priceTypeCode'] ?? 'FIXED';
        _basePriceCtrl.text = next.fields['basePrice'] ?? '';
        _currencyCtrl.text = next.fields['currencyCode'] ?? 'ARS';
        _stockStatusCtrl.text = next.fields['stockStatusCode'] ?? '';
        _tagsCtrl.text = next.fields['tags'] ?? '';
        _usesCtrl.text = next.fields['uses'] ?? '';
        _netWeightCtrl.text = next.fields['netWeight'] ?? '';
        _grossWeightCtrl.text = next.fields['grossWeight'] ?? '';
        _volumeCtrl.text = next.fields['volume'] ?? '';
        _heightCtrl.text = next.fields['height'] ?? '';
        _widthCtrl.text = next.fields['width'] ?? '';
        _lengthCtrl.text = next.fields['length'] ?? '';
        _descriptionCtrl.text = next.fields['description'] ?? '';
        _categoryCtrl.text = next.fields['category'] ?? '';
        _statusCode = next.fields['statusCode'] ?? 'DRAFT';
        _featured = next.fields['featured'] == 'true';

        if (_selectedCompanyId == null || _selectedCompanyId!.trim().isEmpty) {
          final companyId = next.fields['companyId'];
          if (companyId != null && companyId.trim().isNotEmpty) {
            setState(() => _selectedCompanyId = companyId.trim());
          }
        }
        final sellerId = next.fields['sellerId'];
        if (sellerId != null && sellerId.trim().isNotEmpty) {
          setState(() => _selectedSellerId = sellerId.trim());
        }
      },
    );
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _slugCtrl, _skuCtrl,
      _priceTypeCtrl, _basePriceCtrl, _currencyCtrl, _stockStatusCtrl,
      _tagsCtrl, _usesCtrl, _netWeightCtrl, _grossWeightCtrl, _volumeCtrl,
      _heightCtrl, _widthCtrl, _lengthCtrl, _descriptionCtrl, _categoryCtrl,
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
      stockStatusCode: _stockStatusCtrl.text.trim().toUpperCase(),
      tags: _tagsCtrl.text.trim(),
      uses: _usesCtrl.text.trim(),
      netWeight: _netWeightCtrl.text.trim(),
      grossWeight: _grossWeightCtrl.text.trim(),
      volume: _volumeCtrl.text.trim(),
      height: _heightCtrl.text.trim(),
      width: _widthCtrl.text.trim(),
      length: _lengthCtrl.text.trim(),
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
    final isEdit = widget.productId != null;
    final auth = ref.watch(authNotifierProvider);
    final tenantsAsync = auth.isAdminGlobal ? ref.watch(_tenantsLookupProvider) : null;
    final companyForSellers = auth.isAdminGlobal ? _selectedCompanyId : auth.tenantId;
    final sellersAsync = ref.watch(_sellersLookupProvider(companyForSellers));

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
                            onChanged: (v) => setState(() => _selectedCompanyId = v),
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
                        if (sellers.isEmpty) return const SizedBox.shrink();
                        if (_selectedSellerId == null && sellers.length == 1) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && _selectedSellerId == null) {
                              setState(() => _selectedSellerId = sellers.first.id);
                            }
                          });
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey(_selectedSellerId ?? 'seller-none'),
                          initialValue: _selectedSellerId,
                          decoration: const InputDecoration(labelText: 'Seller *'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                          items: sellers
                              .map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedSellerId = v),
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
                    AppTextField(
                      label: 'Tipo de precio *',
                      hint: 'FIXED / CONSULT',
                      controller: _priceTypeCtrl,
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
                      label: 'Moneda',
                      controller: _currencyCtrl,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Categoría',
                      controller: _categoryCtrl,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Estado de stock',
                      hint: 'IN_STOCK / OUT_OF_STOCK',
                      controller: _stockStatusCtrl,
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SizedNumberField(label: 'Peso neto', controller: _netWeightCtrl),
                        _SizedNumberField(label: 'Peso bruto', controller: _grossWeightCtrl),
                        _SizedNumberField(label: 'Volumen', controller: _volumeCtrl),
                        _SizedNumberField(label: 'Alto', controller: _heightCtrl),
                        _SizedNumberField(label: 'Ancho', controller: _widthCtrl),
                        _SizedNumberField(label: 'Largo', controller: _lengthCtrl),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                            imageUrl: null,
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

class _SizedNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _SizedNumberField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width >= 620 ? 170 : double.infinity,
      child: AppTextField(
        label: label,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return null;
          return double.tryParse(v.trim()) == null ? 'Número inválido' : null;
        },
      ),
    );
  }
}
