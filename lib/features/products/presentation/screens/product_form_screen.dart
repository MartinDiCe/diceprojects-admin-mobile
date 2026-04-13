import 'dart:developer';
import 'dart:io';

import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

String _slugify(String input) {
  var s = input.toLowerCase().trim();
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to   = 'aaaaaeeeeiiiioooooussunc';
  for (var i = 0; i < from.length; i++) { s = s.replaceAll(from[i], to[i]); }
  s = s.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
  s = s.replaceAll(RegExp(r'\s+'), '-');
  s = s.replaceAll(RegExp(r'-{2,}'), '-');
  return s;
}

class _LabeledOption { final String value; final String label; const _LabeledOption({required this.value, required this.label}); }
class _IdNameOption { final String id; final String label; const _IdNameOption({required this.id, required this.label}); }

const _priceTypeOptions = [
  _LabeledOption(value: 'STANDARD',  label: 'Estándar'),
  _LabeledOption(value: 'RETAIL',    label: 'Minorista'),
  _LabeledOption(value: 'WHOLESALE', label: 'Mayorista'),
  _LabeledOption(value: 'PREMIUM',   label: 'Premium'),
  _LabeledOption(value: 'FIXED',     label: 'Fijo (requiere precio base)'),
  _LabeledOption(value: 'CONSULT',   label: 'Consultar precio'),
];
const _currencyOptions  = [ _LabeledOption(value: 'ARS', label: 'ARS — Peso argentino'), _LabeledOption(value: 'USD', label: 'USD — Dólar'), _LabeledOption(value: 'EUR', label: 'EUR — Euro') ];
const _statusOptions    = [ _LabeledOption(value: 'DRAFT', label: 'Borrador'), _LabeledOption(value: 'ACTIVE', label: 'Activo'), _LabeledOption(value: 'INACTIVE', label: 'Inactivo') ];
const _stockStatusOptions = [ _LabeledOption(value: '', label: 'Sin estado'), _LabeledOption(value: 'IN_STOCK', label: 'En stock'), _LabeledOption(value: 'OUT_OF_STOCK', label: 'Sin stock'), _LabeledOption(value: 'LOW_STOCK', label: 'Stock bajo') ];

final _productTypesProvider = FutureProvider.autoDispose<List<_IdNameOption>>((ref) async { final d = ref.watch(dioProvider); final r = await d.get('/v1/product-types'); final l = r.data is List ? r.data as List : []; return l.map((e) => _IdNameOption(id: e['typeId']?.toString() ?? '', label: e['name']?.toString() ?? '')).where((o) => o.id.isNotEmpty).toList(); });
final _storageConditionsProvider = FutureProvider.autoDispose<List<_IdNameOption>>((ref) async { final d = ref.watch(dioProvider); final r = await d.get('/v1/storage-conditions'); final l = r.data is List ? r.data as List : []; return l.map((e) => _IdNameOption(id: e['conditionId']?.toString() ?? '', label: e['name']?.toString() ?? '')).where((o) => o.id.isNotEmpty).toList(); });
final _brandsProvider = FutureProvider.autoDispose<List<_IdNameOption>>((ref) async { final d = ref.watch(dioProvider); final r = await d.get('/v1/brands'); final l = r.data is List ? r.data as List : []; return l.map((e) => _IdNameOption(id: e['brandId']?.toString() ?? '', label: e['name']?.toString() ?? '')).where((o) => o.id.isNotEmpty).toList(); });
final _uomProvider = FutureProvider.autoDispose<List<_IdNameOption>>((ref) async { final d = ref.watch(dioProvider); final r = await d.get('/v1/unit-of-measure'); final l = r.data is List ? r.data as List : []; return l.map((e) => _IdNameOption(id: e['code']?.toString() ?? '', label: '${e["name"] ?? ""} (${e["code"] ?? ""})')).where((o) => o.id.isNotEmpty).toList(); });
final _sellersProvider = FutureProvider.autoDispose.family<List<_IdNameOption>, String?>((ref, cid) async { final d = ref.watch(dioProvider); final q = cid != null ? '?tenantId=$cid&size=200' : '?size=200'; final r = await d.get('/v1/sellers$q'); final raw = r.data; final l = raw is List ? raw : (raw is Map ? (raw['content'] as List? ?? []) : []); return (l as List).map((e) => _IdNameOption(id: e['sellerId']?.toString() ?? '', label: e['name']?.toString() ?? '')).where((o) => o.id.isNotEmpty).toList(); });
final _tenantsProvider = FutureProvider.autoDispose<List<_IdNameOption>>((ref) async { final d = ref.watch(dioProvider); final r = await d.get('/v1/tenants?size=200'); final raw = r.data; final l = raw is List ? raw : (raw is Map ? (raw['content'] as List? ?? []) : []); return (l as List).map((e) => _IdNameOption(id: (e['tenantId'] ?? e['id'])?.toString() ?? '', label: e['name']?.toString() ?? '')).where((o) => o.id.isNotEmpty).toList(); });

const _sentinel = Object();

class _PFS {
  final bool isLoading; final bool isSaving; final String? error;
  final String name, slug, sku, category, description, priceTypeCode, basePrice, currencyCode, statusCode, stockStatusCode, tags, uses;
  final bool featured, allowFraction, requiresLot, requiresExpiration, requiresSerial;
  final String? productTypeId, storageConditionId, brandId, baseUomCode, companyId, sellerId;
  final String netWeight, grossWeight, volume, height, width, length;
  // alias for compatibility
  Map<String, String?> get fields => name.isEmpty ? {} : {'name': name};
  const _PFS({ this.isLoading = false, this.isSaving = false, this.error, this.name = '', this.slug = '', this.sku = '', this.category = '', this.description = '', this.priceTypeCode = 'STANDARD', this.basePrice = '', this.currencyCode = 'ARS', this.statusCode = 'DRAFT', this.stockStatusCode = '', this.featured = false, this.tags = '', this.uses = '', this.productTypeId, this.storageConditionId, this.brandId, this.baseUomCode, this.allowFraction = false, this.requiresLot = false, this.requiresExpiration = false, this.requiresSerial = false, this.netWeight = '', this.grossWeight = '', this.volume = '', this.height = '', this.width = '', this.length = '', this.companyId, this.sellerId });
  _PFS copyWith({ bool? isLoading, bool? isSaving, String? error, bool clearError = false, String? name, String? slug, String? sku, String? category, String? description, String? priceTypeCode, String? basePrice, String? currencyCode, String? statusCode, String? stockStatusCode, bool? featured, String? tags, String? uses, Object? productTypeId = _sentinel, Object? storageConditionId = _sentinel, Object? brandId = _sentinel, Object? baseUomCode = _sentinel, bool? allowFraction, bool? requiresLot, bool? requiresExpiration, bool? requiresSerial, String? netWeight, String? grossWeight, String? volume, String? height, String? width, String? length, Object? companyId = _sentinel, Object? sellerId = _sentinel }) => _PFS( isLoading: isLoading ?? this.isLoading, isSaving: isSaving ?? this.isSaving, error: clearError ? null : (error ?? this.error), name: name ?? this.name, slug: slug ?? this.slug, sku: sku ?? this.sku, category: category ?? this.category, description: description ?? this.description, priceTypeCode: priceTypeCode ?? this.priceTypeCode, basePrice: basePrice ?? this.basePrice, currencyCode: currencyCode ?? this.currencyCode, statusCode: statusCode ?? this.statusCode, stockStatusCode: stockStatusCode ?? this.stockStatusCode, featured: featured ?? this.featured, tags: tags ?? this.tags, uses: uses ?? this.uses, productTypeId: identical(productTypeId, _sentinel) ? this.productTypeId : productTypeId as String?, storageConditionId: identical(storageConditionId, _sentinel) ? this.storageConditionId : storageConditionId as String?, brandId: identical(brandId, _sentinel) ? this.brandId : brandId as String?, baseUomCode: identical(baseUomCode, _sentinel) ? this.baseUomCode : baseUomCode as String?, allowFraction: allowFraction ?? this.allowFraction, requiresLot: requiresLot ?? this.requiresLot, requiresExpiration: requiresExpiration ?? this.requiresExpiration, requiresSerial: requiresSerial ?? this.requiresSerial, netWeight: netWeight ?? this.netWeight, grossWeight: grossWeight ?? this.grossWeight, volume: volume ?? this.volume, height: height ?? this.height, width: width ?? this.width, length: length ?? this.length, companyId: identical(companyId, _sentinel) ? this.companyId : companyId as String?, sellerId: identical(sellerId, _sentinel) ? this.sellerId : sellerId as String? );
}

class _ProductFormNotifier extends StateNotifier<_PFS> {
  final Dio _dio; final String? productId;
  _ProductFormNotifier(this._dio, this.productId) : super(const _PFS()) { if (productId != null) _load(); }
  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _dio.get('/v1/products/$productId');
      final d = resp.data as Map<String, dynamic>;
      state = state.copyWith( isLoading: false, name: d['name']?.toString() ?? '', slug: d['slug']?.toString() ?? '', sku: d['sku']?.toString() ?? '', category: d['category']?.toString() ?? '', description: d['description']?.toString() ?? '', priceTypeCode: d['priceTypeCode']?.toString() ?? 'STANDARD', basePrice: d['basePrice']?.toString() ?? '', currencyCode: d['currencyCode']?.toString() ?? 'ARS', statusCode: d['statusCode']?.toString() ?? 'DRAFT', stockStatusCode: d['stockStatusCode']?.toString() ?? '', featured: d['featured'] == true, tags: ((d['tags'] as List?)?.cast<String>() ?? []).join(', '), uses: ((d['uses'] as List?)?.cast<String>() ?? []).join(', '), productTypeId: d['productTypeId']?.toString(), storageConditionId: d['storageConditionId']?.toString(), brandId: d['brandId']?.toString(), baseUomCode: d['baseUomCode']?.toString(), allowFraction: d['allowFraction'] == true, requiresLot: d['requiresLot'] == true, requiresExpiration: d['requiresExpiration'] == true, requiresSerial: d['requiresSerial'] == true, netWeight: d['netWeight']?.toString() ?? '', grossWeight: d['grossWeight']?.toString() ?? '', volume: d['volume']?.toString() ?? '', height: d['height']?.toString() ?? '', width: d['width']?.toString() ?? '', length: d['length']?.toString() ?? '', companyId: d['companyId']?.toString(), sellerId: d['sellerId']?.toString() );
    } catch (e) { state = state.copyWith(isLoading: false, error: ErrorHandler.handle(e).message); }
  }
  Future<bool> save(_PFS s) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      List<String> pt(String raw) => raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      final body = <String, dynamic>{ 'name': s.name.trim(), 'slug': s.slug.trim(), 'companyId': s.companyId ?? '', 'sellerId': s.sellerId ?? '', 'priceTypeCode': s.priceTypeCode, 'statusCode': s.statusCode, 'featured': s.featured, if (s.sku.isNotEmpty) 'sku': s.sku.trim(), if (s.category.isNotEmpty) 'category': s.category.trim(), if (s.description.isNotEmpty) 'description': s.description.trim(), if (s.basePrice.isNotEmpty && double.tryParse(s.basePrice) != null) 'basePrice': double.parse(s.basePrice), 'currencyCode': s.currencyCode, if (s.stockStatusCode.isNotEmpty) 'stockStatusCode': s.stockStatusCode, if (s.tags.isNotEmpty) 'tags': pt(s.tags), if (s.uses.isNotEmpty) 'uses': pt(s.uses), if (s.productTypeId != null) 'productTypeId': s.productTypeId, if (s.storageConditionId != null) 'storageConditionId': s.storageConditionId, if (s.brandId != null) 'brandId': s.brandId, if (s.baseUomCode != null) 'baseUomCode': s.baseUomCode, 'allowFraction': s.allowFraction, 'requiresLot': s.requiresLot, 'requiresExpiration': s.requiresExpiration, 'requiresSerial': s.requiresSerial, if (s.netWeight.isNotEmpty) 'netWeight': double.tryParse(s.netWeight), if (s.grossWeight.isNotEmpty) 'grossWeight': double.tryParse(s.grossWeight), if (s.volume.isNotEmpty) 'volume': double.tryParse(s.volume), if (s.height.isNotEmpty) 'height': double.tryParse(s.height), if (s.width.isNotEmpty) 'width': double.tryParse(s.width), if (s.length.isNotEmpty) 'length': double.tryParse(s.length) };
      if (productId == null) { await _dio.post('/v1/products', data: body); } else { await _dio.put('/v1/products/$productId', data: body); }
      state = state.copyWith(isSaving: false); return true;
    } catch (e) { log('save error: $e'); state = state.copyWith(isSaving: false, error: ErrorHandler.handle(e).message); return false; }
  }
}

final _productFormProvider = StateNotifierProvider.autoDispose.family<_ProductFormNotifier, _PFS, String?>((ref, id) => _ProductFormNotifier(ref.watch(dioProvider), id));

// ─────────────────────────────────────────────── Screen ─────────────────────

class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  const ProductFormScreen({super.key, this.productId});
  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl, _slugCtrl, _skuCtrl, _categoryCtrl, _descriptionCtrl, _basePriceCtrl, _tagsCtrl, _usesCtrl, _netWeightCtrl, _grossWeightCtrl, _volumeCtrl, _heightCtrl, _widthCtrl, _lengthCtrl;
  bool _slugTouched = false;
  String _priceTypeCode = 'STANDARD', _currencyCode = 'ARS', _statusCode = 'DRAFT', _stockStatusCode = '';
  bool _featured = false, _allowFraction = false, _requiresLot = false, _requiresExpiration = false, _requiresSerial = false;
  String? _productTypeId, _storageConditionId, _brandId, _baseUomCode, _selectedCompanyId, _selectedSellerId;
  bool _populated = false;

  // ── Images ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _images = [];
  bool _imagesLoading = false;
  final Map<int, bool> _uploadingSlot = {}; // slot index → uploading

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(); _slugCtrl = TextEditingController(); _skuCtrl = TextEditingController(); _categoryCtrl = TextEditingController(); _descriptionCtrl = TextEditingController(); _basePriceCtrl = TextEditingController(); _tagsCtrl = TextEditingController(); _usesCtrl = TextEditingController(); _netWeightCtrl = TextEditingController(); _grossWeightCtrl = TextEditingController(); _volumeCtrl = TextEditingController(); _heightCtrl = TextEditingController(); _widthCtrl = TextEditingController(); _lengthCtrl = TextEditingController();
    _nameCtrl.addListener(_onNameChanged);
    if (widget.productId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadImages());
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _slugCtrl, _skuCtrl, _categoryCtrl, _descriptionCtrl, _basePriceCtrl, _tagsCtrl, _usesCtrl, _netWeightCtrl, _grossWeightCtrl, _volumeCtrl, _heightCtrl, _widthCtrl, _lengthCtrl]) { c.dispose(); }
    super.dispose();
  }

  void _onNameChanged() { if (!_slugTouched) { _slugCtrl.text = _slugify(_nameCtrl.text); } }

  void _populateFromState(_PFS s) {
    if (_populated || s.name.isEmpty) return;
    _nameCtrl.text = s.name; _slugCtrl.text = s.slug; _skuCtrl.text = s.sku; _categoryCtrl.text = s.category; _descriptionCtrl.text = s.description; _basePriceCtrl.text = s.basePrice; _tagsCtrl.text = s.tags; _usesCtrl.text = s.uses; _netWeightCtrl.text = s.netWeight; _grossWeightCtrl.text = s.grossWeight; _volumeCtrl.text = s.volume; _heightCtrl.text = s.height; _widthCtrl.text = s.width; _lengthCtrl.text = s.length;
    setState(() { _priceTypeCode = s.priceTypeCode; _currencyCode = s.currencyCode; _statusCode = s.statusCode; _stockStatusCode = s.stockStatusCode; _featured = s.featured; _productTypeId = s.productTypeId; _storageConditionId = s.storageConditionId; _brandId = s.brandId; _baseUomCode = s.baseUomCode; _allowFraction = s.allowFraction; _requiresLot = s.requiresLot; _requiresExpiration = s.requiresExpiration; _requiresSerial = s.requiresSerial; _selectedCompanyId = s.companyId; _selectedSellerId = s.sellerId; _populated = true; _slugTouched = s.slug.isNotEmpty; });
  }

  Future<void> _loadImages() async {
    if (widget.productId == null) return;
    setState(() => _imagesLoading = true);
    try {
      final auth = ref.read(authNotifierProvider);
      final companyId = auth.isAdminGlobal ? _selectedCompanyId : auth.tenantId;
      final resp = await ref.read(dioProvider).get(
        '/v1/products/${widget.productId}/images',
        queryParameters: companyId != null ? {'companyId': companyId} : null,
      );
      final list = (resp.data as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      if (mounted) setState(() { _images = list; _imagesLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _imagesLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(int slot) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _uploadingSlot[slot] = true);
    try {
      final auth = ref.read(authNotifierProvider);
      final companyId = (auth.isAdminGlobal ? _selectedCompanyId : auth.tenantId) ?? '';
      final bytes = await File(picked.path).readAsBytes();
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: 'image_$slot.jpg',
            contentType: DioMediaType('image', 'jpeg')),
        'sortOrder': slot,
        if (companyId.isNotEmpty) 'companyId': companyId,
      });
      final dio = ref.read(dioProvider);
      await dio.post('/v1/products/${widget.productId}/images/upload', data: formData);
      await _loadImages();
    } catch (e) {
      if (mounted) _snack('Error al subir imagen: ${ErrorHandler.handle(e).message}');
    } finally {
      if (mounted) setState(() => _uploadingSlot.remove(slot));
    }
  }

  Future<void> _deleteImage(String imageId) async {
    try {
      await ref.read(dioProvider).delete('/v1/products/${widget.productId}/images/$imageId');
      await _loadImages();
    } catch (e) {
      if (mounted) _snack('Error al eliminar imagen: ${ErrorHandler.handle(e).message}');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authNotifierProvider);
    final cid = auth.isAdminGlobal ? _selectedCompanyId : (auth.tenantId ?? _selectedCompanyId);
    if (cid == null || cid.isEmpty) { _snack('Seleccioná una empresa'); return; }
    if (_selectedSellerId == null || _selectedSellerId!.isEmpty) { _snack('Seleccioná un vendedor'); return; }
    final s = _PFS( name: _nameCtrl.text.trim(), slug: _slugCtrl.text.trim(), sku: _skuCtrl.text.trim(), category: _categoryCtrl.text.trim(), description: _descriptionCtrl.text.trim(), priceTypeCode: _priceTypeCode, basePrice: _basePriceCtrl.text.trim(), currencyCode: _currencyCode, statusCode: _statusCode, stockStatusCode: _stockStatusCode, featured: _featured, tags: _tagsCtrl.text.trim(), uses: _usesCtrl.text.trim(), productTypeId: _productTypeId, storageConditionId: _storageConditionId, brandId: _brandId, baseUomCode: _baseUomCode, allowFraction: _allowFraction, requiresLot: _requiresLot, requiresExpiration: _requiresExpiration, requiresSerial: _requiresSerial, netWeight: _netWeightCtrl.text.trim(), grossWeight: _grossWeightCtrl.text.trim(), volume: _volumeCtrl.text.trim(), height: _heightCtrl.text.trim(), width: _widthCtrl.text.trim(), length: _lengthCtrl.text.trim(), companyId: cid, sellerId: _selectedSellerId );
    final ok = await ref.read(_productFormProvider(widget.productId).notifier).save(s);
    if (ok && mounted) context.pop();
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final ns = ref.watch(_productFormProvider(widget.productId));
    final auth = ref.watch(authNotifierProvider);
    if (!_populated && ns.name.isNotEmpty) _populateFromState(ns);
    if (!auth.isAdminGlobal && _selectedCompanyId == null && auth.tenantId != null) _selectedCompanyId = auth.tenantId;
    if (ns.isLoading) return const AppPageScaffold(title: 'Producto', body: LoadingState());
    return AppPageScaffold(
      title: widget.productId == null ? 'Nuevo Producto' : 'Editar Producto',
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (ns.error != null) ...[_Banner(ns.error!), const SizedBox(height: 12)],
            // Empresa/Vendedor
            _Card(title: 'Empresa y Vendedor', icon: Icons.business_rounded, children: [
              if (auth.isAdminGlobal) ...[
                _AsyncDD(label: 'Empresa *', value: _selectedCompanyId, async_: ref.watch(_tenantsProvider), onChanged: (v) => setState(() { _selectedCompanyId = v; _selectedSellerId = null; }), nullable: true),
                const SizedBox(height: 12),
              ],
              _AsyncDD(label: 'Vendedor *', value: _selectedSellerId, async_: ref.watch(_sellersProvider(_selectedCompanyId)), onChanged: (v) => setState(() => _selectedSellerId = v), nullable: true),
            ]),
            const SizedBox(height: 12),
            // Básico
            _Card(title: 'Información Básica', icon: Icons.info_outline_rounded, children: [
              AppTextField(controller: _nameCtrl, label: 'Nombre *', hint: 'Nombre del producto', helperText: 'Nombre completo del producto tal como aparecerá en el catálogo', validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _slugCtrl, decoration: _dec('Slug *', 'url-del-producto', helper: 'Identificador único en la URL. Se genera automáticamente desde el nombre. Solo letras, números y guiones.'), onChanged: (_) => setState(() => _slugTouched = true), validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
              const SizedBox(height: 12),
              AppTextField(controller: _skuCtrl, label: 'SKU', hint: 'Ej: PROD-001', helperText: 'Código interno del producto (stock-keeping unit). Opcional.'),
              const SizedBox(height: 12),
              AppTextField(controller: _categoryCtrl, label: 'Categoría', hint: 'Ej: Electrónica, Alimentos, Ropa…', helperText: 'Agrupación libre del producto. No es un catálogo cerrado.'),
              const SizedBox(height: 12),
              AppTextField(controller: _descriptionCtrl, label: 'Descripción', hint: 'Descripción detallada del producto…', maxLines: 3, helperText: 'Texto libre visible en el detalle del producto.'),
            ]),
            const SizedBox(height: 12),
            // Precio
            _Card(title: 'Precio', icon: Icons.attach_money_rounded, children: [
              _StaticDD(label: 'Tipo de precio *', value: _priceTypeCode, options: _priceTypeOptions, onChanged: (v) => setState(() => _priceTypeCode = v ?? 'STANDARD')),
              const SizedBox(height: 12),
              AppTextField(controller: _basePriceCtrl, label: 'Precio base', hint: '0.00', helperText: 'Precio de referencia en la moneda seleccionada. Opcional.', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              _StaticDD(label: 'Moneda', value: _currencyCode, options: _currencyOptions, onChanged: (v) => setState(() => _currencyCode = v ?? 'ARS')),
            ]),
            const SizedBox(height: 12),
            // Estado
            _Card(title: 'Estado', icon: Icons.toggle_on_rounded, children: [
              _StaticDD(label: 'Estado del producto', value: _statusCode, options: _statusOptions, onChanged: (v) => setState(() => _statusCode = v ?? 'DRAFT')),
              const SizedBox(height: 12),
              _StaticDD(label: 'Estado de stock', value: _stockStatusCode, options: _stockStatusOptions, onChanged: (v) => setState(() => _stockStatusCode = v ?? '')),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Producto destacado'), value: _featured, onChanged: (v) => setState(() => _featured = v ?? false)),
              const SizedBox(height: 4),
              AppTextField(controller: _tagsCtrl, label: 'Tags', hint: 'Ej: popular, nuevo, oferta', helperText: 'Palabras clave separadas por coma. Facilitan la búsqueda y filtrado del producto.'),
              const SizedBox(height: 12),
              AppTextField(controller: _usesCtrl, label: 'Usos', hint: 'Ej: cocina, jardín, hogar', helperText: 'Usos o aplicaciones del producto, separados por coma.'),
            ]),
            const SizedBox(height: 12),
            // Clasificación
            _Card(title: 'Clasificación', icon: Icons.category_rounded, children: [
              _AsyncDD(label: 'Tipo de producto', value: _productTypeId, async_: ref.watch(_productTypesProvider), onChanged: (v) => setState(() => _productTypeId = v), nullable: true),
              const SizedBox(height: 12),
              _AsyncDD(label: 'Condición de almacenamiento', value: _storageConditionId, async_: ref.watch(_storageConditionsProvider), onChanged: (v) => setState(() => _storageConditionId = v), nullable: true),
              const SizedBox(height: 12),
              _AsyncDD(label: 'Marca', value: _brandId, async_: ref.watch(_brandsProvider), onChanged: (v) => setState(() => _brandId = v), nullable: true, emptyHint: 'Sin marcas. Creálas en Productos › Marcas.'),
              const SizedBox(height: 12),
              _AsyncDD(label: 'Unidad de medida base', value: _baseUomCode, async_: ref.watch(_uomProvider), onChanged: (v) => setState(() => _baseUomCode = v), nullable: true),
              const Divider(height: 24),
              const Text('Trazabilidad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Permite fracción'), value: _allowFraction, onChanged: (v) => setState(() => _allowFraction = v ?? false)),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Requiere lote'), value: _requiresLot, onChanged: (v) => setState(() => _requiresLot = v ?? false)),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Requiere vencimiento'), value: _requiresExpiration, onChanged: (v) => setState(() => _requiresExpiration = v ?? false)),
              CheckboxListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Requiere serial'), value: _requiresSerial, onChanged: (v) => setState(() => _requiresSerial = v ?? false)),
            ]),
            const SizedBox(height: 12),
            // Dimensiones
            _Card(title: 'Dimensiones', icon: Icons.straighten_rounded, children: [
              Row(children: [Expanded(child: _DimF(_netWeightCtrl, 'Peso neto (kg)')), const SizedBox(width: 12), Expanded(child: _DimF(_grossWeightCtrl, 'Peso bruto (kg)'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _DimF(_volumeCtrl, 'Volumen (m³)')), const SizedBox(width: 12), Expanded(child: _DimF(_heightCtrl, 'Alto (cm)'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _DimF(_widthCtrl, 'Ancho (cm)')), const SizedBox(width: 12), Expanded(child: _DimF(_lengthCtrl, 'Largo (cm)'))]),
            ]),
            const SizedBox(height: 12),
            // Imágenes — solo en modo edición
            if (widget.productId != null)
              _Card(
                title: 'Fotos del Producto',
                icon: Icons.photo_library_rounded,
                children: [
                  Text(
                    'Hasta 5 fotos: la primera es la imagen principal. Toca un slot vacío para agregar.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (_imagesLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: 5,
                      itemBuilder: (ctx, slot) {
                        final img = _images.firstWhere(
                          (i) => (i['sortOrder'] as num?)?.toInt() == slot,
                          orElse: () => {},
                        );
                        final hasImage = img.isNotEmpty;
                        final imageId = img['imageId']?.toString();
                        final url = img['url']?.toString();
                        final uploading = _uploadingSlot[slot] == true;

                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: uploading ? null : () => _pickAndUploadImage(slot),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.border.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: slot == 0 ? AppColors.accent.withValues(alpha: 0.6) : AppColors.border,
                                    width: slot == 0 ? 2 : 1,
                                  ),
                                ),
                                child: uploading
                                    ? const Center(child: CircularProgressIndicator())
                                    : hasImage && url != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(9),
                                            child: Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                                              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: AppColors.textSecondary)),
                                          )
                                        : Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(slot == 0 ? Icons.star_rounded : Icons.add_photo_alternate_outlined,
                                                  color: slot == 0 ? AppColors.accent : AppColors.textSecondary, size: 28),
                                              if (slot == 0)
                                                Text('Principal', style: TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                              ),
                            ),
                            // Delete button
                            if (hasImage && imageId != null && !uploading)
                              Positioned(
                                top: 4, right: 4,
                                child: GestureDetector(
                                  onTap: () => _deleteImage(imageId),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            const SizedBox(height: 24),
            AppButton(label: ns.isSaving ? 'Guardando…' : (widget.productId == null ? 'Crear Producto' : 'Guardar cambios'), onPressed: ns.isSaving ? null : _save),
          ],
        ),
      ),
    );
  }
}

InputDecoration _dec(String label, String hint, {String? helper}) => InputDecoration(labelText: label, hintText: hint, helperText: helper, helperMaxLines: 3, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

class _Card extends StatelessWidget {
  final String title; final IconData icon; final List<Widget> children;
  const _Card({required this.title, required this.icon, required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 3))]),
    child: ExpansionTile(initiallyExpanded: true, leading: Icon(icon, color: AppColors.accent, size: 20), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16), expandedCrossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

class _StaticDD extends StatelessWidget {
  final String label, value; final List<_LabeledOption> options; final ValueChanged<String?> onChanged;
  const _StaticDD({required this.label, required this.value, required this.options, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(value: options.any((o) => o.value == value) ? value : options.first.value, decoration: _dec(label, ''), items: options.map((o) => DropdownMenuItem(value: o.value, child: Text(o.label))).toList(), onChanged: onChanged);
}

class _AsyncDD extends StatelessWidget {
  final String label; final String? value; final AsyncValue<List<_IdNameOption>> async_; final ValueChanged<String?> onChanged; final bool nullable; final String? emptyHint;
  const _AsyncDD({required this.label, required this.value, required this.async_, required this.onChanged, this.nullable = false, this.emptyHint});
  @override
  Widget build(BuildContext context) => async_.when(
    loading: () => TextFormField(enabled: false, decoration: _dec(label, 'Cargando…')),
    error: (_, __) => TextFormField(enabled: false, decoration: _dec(label, 'Error al cargar')),
    data: (items) {
      final valid = items.any((o) => o.id == value) ? value : null;
      if (items.isEmpty && emptyHint != null) {
        return TextFormField(enabled: false, decoration: _dec(label, emptyHint!, helper: emptyHint));
      }
      final all = [if (nullable) const _IdNameOption(id: '', label: '— Sin seleccionar —'), ...items];
      return DropdownButtonFormField<String>(value: valid, decoration: _dec(label, ''), isExpanded: true, items: all.map((o) => DropdownMenuItem(value: o.id.isEmpty ? null : o.id, child: Text(o.label, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v));
    },
  );
}

class _DimF extends StatelessWidget {
  final TextEditingController ctrl; final String label;
  const _DimF(this.ctrl, this.label);
  @override
  Widget build(BuildContext context) => TextFormField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _dec(label, ''));
}

class _Banner extends StatelessWidget {
  final String message;
  const _Banner(this.message);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF9A9A))), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)))]));
}
