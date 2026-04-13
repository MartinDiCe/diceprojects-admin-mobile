import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          'priceTypeCode': data['priceTypeCode']?.toString() ?? 'FIXED',
          'basePrice': data['basePrice']?.toString(),
          'description': data['description']?.toString(),
          'category': data['category']?.toString(),
        },
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: ErrorHandler.handle(e).message);
    }
  }

  Future<bool> save({
    required String name,
    required String slug,
    required String companyId,
    required String priceTypeCode,
    String? sku,
    String? description,
    String? category,
    String? basePrice,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final body = {
        'name': name,
        'slug': slug,
        'companyId': companyId,
        'priceTypeCode': priceTypeCode,
        if (sku != null && sku.isNotEmpty) 'sku': sku,
        if (description != null && description.isNotEmpty)
          'description': description,
        if (category != null && category.isNotEmpty) 'category': category,
        if (basePrice != null && basePrice.isNotEmpty)
          'basePrice': double.tryParse(basePrice),
      };
      if (productId == null) {
        await _dio.post('/v1/products', data: body);
      } else {
        await _dio.put('/v1/products/$productId', data: body);
      }
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
          isSaving: false, error: ErrorHandler.handle(e).message);
      return false;
    }
  }
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
  late final TextEditingController _companyIdCtrl;
  late final TextEditingController _priceTypeCtrl;
  late final TextEditingController _basePriceCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _categoryCtrl;

  @override
  void initState() {
    super.initState();
    final fields =
        ref.read(productFormNotifierProvider(widget.productId)).fields;
    _nameCtrl = TextEditingController(text: fields['name'] ?? '');
    _slugCtrl = TextEditingController(text: fields['slug'] ?? '');
    _skuCtrl = TextEditingController(text: fields['sku'] ?? '');
    _companyIdCtrl = TextEditingController(text: fields['companyId'] ?? '');
    _priceTypeCtrl =
        TextEditingController(text: fields['priceTypeCode'] ?? 'FIXED');
    _basePriceCtrl = TextEditingController(text: fields['basePrice'] ?? '');
    _descriptionCtrl =
        TextEditingController(text: fields['description'] ?? '');
    _categoryCtrl = TextEditingController(text: fields['category'] ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _slugCtrl, _skuCtrl, _companyIdCtrl,
      _priceTypeCtrl, _basePriceCtrl, _descriptionCtrl, _categoryCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier =
        ref.read(productFormNotifierProvider(widget.productId).notifier);
    final ok = await notifier.save(
      name: _nameCtrl.text.trim(),
      slug: _slugCtrl.text.trim(),
      companyId: _companyIdCtrl.text.trim(),
      priceTypeCode: _priceTypeCtrl.text.trim(),
      sku: _skuCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      basePrice: _basePriceCtrl.text.trim(),
    );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productFormNotifierProvider(widget.productId));
    final isEdit = widget.productId != null;

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
                    AppTextField(
                      label: 'Company ID *',
                      controller: _companyIdCtrl,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
                      label: 'Categoría',
                      controller: _categoryCtrl,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      label: 'Descripción',
                      controller: _descriptionCtrl,
                      maxLines: 3,
                    ),
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
