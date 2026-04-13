import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Form State ──────────────────────────────

class _SellerFormState {
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const _SellerFormState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

  _SellerFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) =>
      _SellerFormState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: clearError ? null : (error ?? this.error),
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class _SellerFormNotifier extends StateNotifier<_SellerFormState> {
  final Dio _dio;
  final String? sellerId;

  _SellerFormNotifier(this._dio, this.sellerId)
      : super(const _SellerFormState());

  Future<Map<String, dynamic>?> loadSeller() async {
    if (sellerId == null) return null;
    state = state.copyWith(isLoading: true);
    try {
      final resp = await _dio.get('/v1/sellers/$sellerId');
      state = state.copyWith(isLoading: false);
      return resp.data as Map<String, dynamic>;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> save({
    required String sellerCode,
    required String name,
    String? description,
    String? email,
    String? phone,
    String? logoUrl,
    String? websiteUrl,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final body = {
        if (sellerId == null) 'sellerCode': sellerCode,
        'name': name,
        if (description?.isNotEmpty ?? false) 'description': description,
        if (email?.isNotEmpty ?? false) 'email': email,
        if (phone?.isNotEmpty ?? false) 'phone': phone,
        if (logoUrl?.isNotEmpty ?? false) 'logoUrl': logoUrl,
        if (websiteUrl?.isNotEmpty ?? false) 'websiteUrl': websiteUrl,
      };
      if (sellerId == null) {
        await _dio.post('/v1/sellers', data: body);
      } else {
        await _dio.put('/v1/sellers/$sellerId', data: body);
      }
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }
}

final _sellerFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<_SellerFormNotifier, _SellerFormState, String?>(
  (ref, sellerId) => _SellerFormNotifier(ref.watch(dioProvider), sellerId),
);

// ────────────────────────────── Screen ──────────────────────────────

class SellerFormScreen extends ConsumerStatefulWidget {
  final String? sellerId;

  const SellerFormScreen({super.key, required this.sellerId});

  @override
  ConsumerState<SellerFormScreen> createState() => _SellerFormScreenState();
}

class _SellerFormScreenState extends ConsumerState<SellerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _logoCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _logoCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.sellerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final data = await ref
            .read(_sellerFormNotifierProvider(widget.sellerId).notifier)
            .loadSeller();
        if (data != null && mounted) {
          _nameCtrl.text = data['name']?.toString() ?? '';
          _descCtrl.text = data['description']?.toString() ?? '';
          _emailCtrl.text = data['email']?.toString() ?? '';
          _phoneCtrl.text = data['phone']?.toString() ?? '';
          _logoCtrl.text = data['logoUrl']?.toString() ?? '';
          _websiteCtrl.text = data['websiteUrl']?.toString() ?? '';
          setState(() {});
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final ok = await ref
        .read(_sellerFormNotifierProvider(widget.sellerId).notifier)
        .save(
          sellerCode: _codeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          logoUrl: _logoCtrl.text.trim(),
          websiteUrl: _websiteCtrl.text.trim(),
        );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_sellerFormNotifierProvider(widget.sellerId));
    final isEdit = widget.sellerId != null;

    return AppPageScaffold(
      title: isEdit ? 'Editar vendedor' : 'Nuevo vendedor',
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isEdit)
                      AppTextField(
                        controller: _codeCtrl,
                        label: 'Código',
                        hint: 'Ej: VND-001',
                        validator: (v) =>
                            (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                      ),
                    if (!isEdit) const SizedBox(height: 12),
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Nombre',
                      hint: 'Nombre del vendedor',
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _descCtrl,
                      label: 'Descripción',
                      hint: 'Descripción opcional',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _emailCtrl,
                      label: 'Email',
                      hint: 'correo@ejemplo.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Teléfono',
                      hint: '+54 11 1234 5678',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _logoCtrl,
                      label: 'URL del logo',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _websiteCtrl,
                      label: 'Sitio web',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 24),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    AppButton(
                      label: isEdit ? 'Guardar cambios' : 'Crear vendedor',
                      isLoading: state.isSaving,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
