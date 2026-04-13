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
import 'package:app_diceprojects_admin/core/ui/widgets/confirm_dialog.dart';
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
  List<_PhotoItem> _photos = [];
  bool _photosLoading = false;
  bool _isUploading = false;
  int _uploadDone = 0;
  int _uploadTotal = 0;

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
    setState(() => _photosLoading = true);
    try {
      final resp = await ref.read(dioProvider).get('/v1/products/${widget.productId}/images');
      final list = (resp.data as List? ?? []).map((e) => e as Map<String, dynamic>).toList();
      if (mounted) {
        setState(() {
          _photos = list.map((e) => _PhotoItem(
            imageId: e['imageId']?.toString(),
            url: e['url']?.toString(),
            status: _PhotoStatus.loaded,
            sortOrder: (e['sortOrder'] as num?)?.toInt() ?? 0,
          )).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          _photosLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _photosLoading = false);
    }
  }

  Future<void> _pickAndUploadMultiple() async {
    if (_isUploading) return;
    final loadedCount = _photos.where((p) => p.status == _PhotoStatus.loaded).length;
    final remaining = 5 - loadedCount;
    if (remaining <= 0) return;
    List<XFile> selected;
    try {
      selected = await ImagePicker().pickMultiImage(imageQuality: 85);
    } catch (_) { return; }
    if (selected.isEmpty || !mounted) return;
    if (selected.length > remaining) {
      selected = selected.take(remaining).toList();
      _snack('Se agregaron las primeras $remaining foto(s). Máximo 5 en total.');
    }
    final nextSort = _photos.isEmpty ? 0 : (_photos.map((p) => p.sortOrder).fold(0, (a, b) => a > b ? a : b) + 1);
    final placeholders = selected.asMap().entries.map((e) => _PhotoItem(
      localFile: File(e.value.path), status: _PhotoStatus.uploading, sortOrder: nextSort + e.key,
    )).toList();
    setState(() { _photos = [..._photos, ...placeholders]; _isUploading = true; _uploadDone = 0; _uploadTotal = selected.length; });
    for (int i = 0; i < selected.length; i++) {
      final xfile = selected[i];
      final sortOrder = nextSort + i;
      try {
        final bytes = await File(xfile.path).readAsBytes();
        final formData = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: 'img_$sortOrder.jpg', contentType: DioMediaType('image', 'jpeg')),
          'sortOrder': sortOrder,
        });
        await ref.read(dioProvider).post('/v1/products/${widget.productId}/images/upload', data: formData);
      } catch (_) {
        if (mounted) {
          final idx = _photos.indexWhere((p) => p.sortOrder == sortOrder && p.status == _PhotoStatus.uploading);
          if (idx >= 0) {
            final updated = List<_PhotoItem>.from(_photos);
            updated[idx] = _PhotoItem(localFile: File(xfile.path), status: _PhotoStatus.error, sortOrder: sortOrder);
            setState(() => _photos = updated);
          }
        }
      }
      if (mounted) setState(() => _uploadDone = i + 1);
    }
    await _loadImages();
    if (mounted) setState(() { _isUploading = false; });
  }

  Future<void> _deleteImage(String imageId) async {
    final confirmed = await ConfirmDialog.show(context,
      title: '¿Eliminar foto?',
      message: 'Esta imagen se eliminará del producto. No se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(dioProvider).delete('/v1/products/${widget.productId}/images/$imageId');
      await _loadImages();
    } catch (_) {
      if (mounted) _snack('No se pudo eliminar la foto. Intentá de nuevo.');
    }
  }

  Widget _buildPhotosCard() {
    final loadedCount = _photos.where((p) => p.status == _PhotoStatus.loaded).length;
    return _Card(
      title: 'Fotos del Producto',
      icon: Icons.photo_library_rounded,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(
              loadedCount == 0 ? 'La primera foto será la imagen principal.' : 'La primera foto es la imagen principal.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )),
            Text('$loadedCount / 5', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: loadedCount >= 5 ? AppColors.error : AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        if (_photosLoading)
          SizedBox(height: 96, child: Row(children: [
            for (var i = 0; i < 3; i++) ...[if (i > 0) const SizedBox(width: 8),
              Container(width: 88, height: 88, decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))],
          ]))
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length + (loadedCount < 5 ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, idx) {
                if (idx == _photos.length) return _AddPhotoCard(enabled: !_isUploading, onTap: _pickAndUploadMultiple);
                final photo = _photos[idx];
                return _PhotoThumb(
                  photo: photo, isPrimary: idx == 0,
                  onDelete: photo.imageId != null && photo.status == _PhotoStatus.loaded ? () => _deleteImage(photo.imageId!) : null,
                );
              },
            ),
          ),
        if (_isUploading && _uploadTotal > 0) ...[const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: _uploadDone / _uploadTotal, backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent))),
          const SizedBox(height: 4),
          Text('Subiendo $_uploadDone de $_uploadTotal foto(s)...',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary))],
      ],
    );
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
            // Fotos — solo en modo edición
            if (widget.productId != null) _buildPhotosCard(),
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

// ── Photo section models & widgets ────────────────────────────────────────

enum _PhotoStatus { loaded, uploading, error }

class _PhotoItem {
  final String? imageId;
  final String? url;
  final File? localFile;
  final _PhotoStatus status;
  final int sortOrder;
  const _PhotoItem({this.imageId, this.url, this.localFile, required this.status, required this.sortOrder});
}

class _PhotoThumb extends StatelessWidget {
  final _PhotoItem photo;
  final bool isPrimary;
  final VoidCallback? onDelete;
  const _PhotoThumb({super.key, required this.photo, required this.isPrimary, this.onDelete});

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (photo.status == _PhotoStatus.uploading) {
      content = Stack(fit: StackFit.expand, children: [
        if (photo.localFile != null) Image.file(photo.localFile!, fit: BoxFit.cover),
        Container(color: Colors.black45, child: const Center(child: SizedBox(width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
      ]);
    } else if (photo.status == _PhotoStatus.error) {
      content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
        const Text('Error', style: TextStyle(fontSize: 10, color: Colors.red)),
      ]);
    } else {
      content = photo.url != null
          ? Image.network(photo.url!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: AppColors.textSecondary))
          : const SizedBox();
    }
    return SizedBox(
      width: 88, height: 88,
      child: Stack(fit: StackFit.expand, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary ? AppColors.accent.withValues(alpha: 0.7) : AppColors.border,
                width: isPrimary ? 2 : 1,
              ),
            ),
            child: content,
          ),
        ),
        if (isPrimary && photo.status == _PhotoStatus.loaded)
          Positioned(bottom: 5, left: 5, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(5)),
            child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
          )),
        if (onDelete != null)
          Positioned(top: 4, right: 4, child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          )),
      ]),
    );
  }
}

class _AddPhotoCard extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _AddPhotoCard({super.key, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1.0 : 0.45,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 88, height: 88,
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_photo_alternate_outlined, size: 26, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text('Agregar', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  final String message;
  const _Banner(this.message);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF9A9A))), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18), const SizedBox(width: 8), Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13)))]));
}
