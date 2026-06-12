import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/image_upload_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/features/sellers/presentation/screens/sellers_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

// ────────────────────────────── Form State ──────────────────────────────

class _SellerFormState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final Map<String, String?> fields;

  const _SellerFormState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.fields = const {},
  });

  _SellerFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    Map<String, String?>? fields,
  }) =>
      _SellerFormState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: error,
        fields: fields ?? this.fields,
      );
}

class SellerFormNotifier extends StateNotifier<_SellerFormState> {
  final Dio _dio;
  final String? sellerId;
  final SellerDto? initialSeller;

  SellerFormNotifier(this._dio, this.sellerId, {this.initialSeller})
      : super(const _SellerFormState()) {
    if (sellerId != null) {
      if (initialSeller != null) {
        _setFromSeller(initialSeller!);
      } else {
        _load();
      }
    }
  }

  void _setFromSeller(SellerDto seller) {
    state = state.copyWith(
      fields: {
        'sellerCode': seller.sellerCode,
        'tenantId': seller.tenantId,
        'name': seller.name,
        'description': seller.description,
        'email': seller.email,
        'phone': seller.phone,
        'taxId': seller.taxId,
        'logoUrl': seller.logoUrl,
        'websiteUrl': seller.websiteUrl,
        'instagramUrl': seller.instagramUrl,
        'facebookUrl': seller.facebookUrl,
        'address': seller.address,
        'city': seller.city,
        'province': seller.province,
        'country': seller.country,
        'postalCode': seller.postalCode,
      },
    );
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      // Prefer a direct-by-id endpoint if available; fallback to list-search.
      try {
        final direct = await _dio.get('/v1/sellers/$sellerId');
        final data = direct.data as Map<String, dynamic>;
        final seller = SellerDto.fromJson(data);
        state = state.copyWith(isLoading: false);
        _setFromSeller(seller);
        return;
      } catch (_) {
        // ignore and fallback below
      }

      final resp = await _dio.get(
        '/v1/sellers',
        queryParameters: {
          'page': 0,
          'size': 50,
          'pageSize': 50,
          'search': sellerId,
        },
      );

      final raw = resp.data;
      final items = (raw is Map && raw['content'] is List)
          ? (raw['content'] as List)
          : (raw is Map && raw['items'] is List)
              ? (raw['items'] as List)
              : (raw is List)
                  ? raw
                  : const <dynamic>[];

      final sellers = items
          .whereType<Map>()
          .map((m) => SellerDto.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      final seller = sellers.firstWhere(
        (s) => s.sellerId == sellerId,
        orElse: () => const SellerDto(
          sellerId: '',
          tenantId: null,
          sellerCode: '',
          name: '',
          active: true,
        ),
      );

      if (seller.sellerId.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'No pudimos cargar el vendedor para editar.',
        );
        return;
      }

      state = state.copyWith(isLoading: false);
      _setFromSeller(seller);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> save({
    required String? sellerCode,
    required String name,
    required String? description,
    required String? email,
    required String? phone,
    required String? taxId,
    required String? logoUrl,
    required String? websiteUrl,
    required String? instagramUrl,
    required String? facebookUrl,
    required String? address,
    required String? city,
    required String? province,
    required String? country,
    required String? postalCode,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final body = {
        if (sellerId == null) 'sellerCode': sellerCode,
        'name': name,
        'description': description,
        'email': email,
        'phone': phone,
        'taxId': taxId,
        'logoUrl': logoUrl,
        'websiteUrl': websiteUrl,
        'instagramUrl': instagramUrl,
        'facebookUrl': facebookUrl,
        'address': address,
        'city': city,
        'province': province,
        'country': country,
        'postalCode': postalCode,
      };

      if (sellerId == null) {
        final resp = await _dio.post('/v1/sellers', data: body);
        state = state.copyWith(isSaving: false);
        final data = resp.data;
        if (data is Map) return (data['sellerId'] ?? data['id'])?.toString();
        return null;
      } else {
        await _dio.put('/v1/sellers/$sellerId', data: body);
      }

      state = state.copyWith(isSaving: false);
      return sellerId;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<String?> uploadLogo({
    required String sellerId,
    required XFile file,
    String? tenantId,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final resp = await _dio.post(
      '/v1/sellers/logo/upload',
      queryParameters: {
        if (tenantId != null && tenantId.trim().isNotEmpty) 'tenantId': tenantId.trim(),
        'sellerId': sellerId,
      },
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = resp.data;
    if (data is Map) return resolveMediaUrl(data['url']?.toString());
    return null;
  }

}

final sellerFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<SellerFormNotifier, _SellerFormState, ({String? sellerId, SellerDto? initialSeller})>(
  (ref, args) => SellerFormNotifier(
    ref.watch(dioProvider),
    args.sellerId,
    initialSeller: args.initialSeller,
  ),
);

// ────────────────────────────── Screen ──────────────────────────────

class SellerFormScreen extends ConsumerStatefulWidget {
  final String? sellerId;

  const SellerFormScreen({
    super.key,
    required this.sellerId,
  });

  @override
  ConsumerState<SellerFormScreen> createState() => _SellerFormScreenState();
}

class _SellerFormScreenState extends ConsumerState<SellerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _sellerCodeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _logoUrlCtrl;
  late final TextEditingController _websiteUrlCtrl;
  late final TextEditingController _instagramUrlCtrl;
  late final TextEditingController _facebookUrlCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _postalCodeCtrl;

  bool _populated = false;
  XFile? _logoFile;

  @override
  void initState() {
    super.initState();
    _sellerCodeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _taxIdCtrl = TextEditingController();
    _logoUrlCtrl = TextEditingController();
    _websiteUrlCtrl = TextEditingController();
    _instagramUrlCtrl = TextEditingController();
    _facebookUrlCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _provinceCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    _postalCodeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _sellerCodeCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _taxIdCtrl.dispose();
    _logoUrlCtrl.dispose();
    _websiteUrlCtrl.dispose();
    _instagramUrlCtrl.dispose();
    _facebookUrlCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _countryCtrl.dispose();
    _postalCodeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    final initialSeller = extra is SellerDto ? extra : null;

    final state = ref.watch(
      sellerFormNotifierProvider((sellerId: widget.sellerId, initialSeller: initialSeller)),
    );
    final notifier = ref.read(
      sellerFormNotifierProvider((sellerId: widget.sellerId, initialSeller: initialSeller)).notifier,
    );

    if (!_populated && state.fields.isNotEmpty) {
      _sellerCodeCtrl.text = state.fields['sellerCode'] ?? '';
      _nameCtrl.text = state.fields['name'] ?? '';
      _descriptionCtrl.text = state.fields['description'] ?? '';
      _emailCtrl.text = state.fields['email'] ?? '';
      _phoneCtrl.text = state.fields['phone'] ?? '';
      _taxIdCtrl.text = state.fields['taxId'] ?? '';
      _logoUrlCtrl.text = state.fields['logoUrl'] ?? '';
      _websiteUrlCtrl.text = state.fields['websiteUrl'] ?? '';
      _instagramUrlCtrl.text = state.fields['instagramUrl'] ?? '';
      _facebookUrlCtrl.text = state.fields['facebookUrl'] ?? '';
      _addressCtrl.text = state.fields['address'] ?? '';
      _cityCtrl.text = state.fields['city'] ?? '';
      _provinceCtrl.text = state.fields['province'] ?? '';
      _countryCtrl.text = state.fields['country'] ?? '';
      _postalCodeCtrl.text = state.fields['postalCode'] ?? '';
      _populated = true;
    }

    return AppPageScaffold(
      title: widget.sellerId == null ? 'Nuevo Vendedor' : 'Editar Vendedor',
      body: state.isLoading
          ? const LoadingState()
          : state.error != null && state.fields.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () => ref.invalidate(
                    sellerFormNotifierProvider((sellerId: widget.sellerId, initialSeller: initialSeller)),
                  ),
                )
              : _buildForm(context, state, notifier),
    );
  }

  Widget _buildForm(
    BuildContext context,
    _SellerFormState state,
    SellerFormNotifier notifier,
  ) {
    final isCreate = widget.sellerId == null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (isCreate) ...[
              AppTextField(
                controller: _sellerCodeCtrl,
                label: 'Código',
                hint: 'SELLER-001',
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              controller: _nameCtrl,
              label: 'Nombre',
              hint: 'Nombre del vendedor',
              validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _descriptionCtrl,
              label: 'Descripción',
              hint: 'Descripción',
              maxLines: 3,
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
              hint: '+54 11 1234-5678',
              keyboardType: TextInputType.phone,
              prefixIcon: _dialCodeForCountry(_countryCtrl.text).isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Center(
                        widthFactor: 1,
                        child: Text(_dialCodeForCountry(_countryCtrl.text)),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _taxIdCtrl,
              label: 'CUIT',
              hint: '20-00000000-0',
            ),
            const SizedBox(height: 12),
            ImageUploadField(
              label: 'Logo del vendedor',
              imageUrl: _logoUrlCtrl.text,
              onChanged: (file) => setState(() {
                _logoFile = file;
                if (file == null) _logoUrlCtrl.clear();
              }),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _logoUrlCtrl,
              label: 'Logo URL',
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _websiteUrlCtrl,
              label: 'Sitio Web',
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            AppTextField(controller: _instagramUrlCtrl, label: 'Instagram URL', keyboardType: TextInputType.url),
            const SizedBox(height: 12),
            AppTextField(controller: _facebookUrlCtrl, label: 'Facebook URL', keyboardType: TextInputType.url),
            const SizedBox(height: 12),
            AppTextField(controller: _addressCtrl, label: 'Dirección'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppTextField(controller: _cityCtrl, label: 'Ciudad')),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(controller: _provinceCtrl, label: 'Provincia')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _countryCtrl,
                    label: 'País',
                    hint: 'Argentina',
                    onChanged: (_) => _applyDialCodeFromCountry(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(controller: _postalCodeCtrl, label: 'CP')),
              ],
            ),
            const SizedBox(height: 24),
            AppButton(
              label: isCreate ? 'Crear vendedor' : 'Guardar',
              isLoading: state.isSaving,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                var logoUrl = _logoUrlCtrl.text.trim().isEmpty ? null : _logoUrlCtrl.text.trim();
                final savedSellerId = await notifier.save(
                  sellerCode: isCreate ? _sellerCodeCtrl.text.trim() : null,
                  name: _nameCtrl.text.trim(),
                  description: _descriptionCtrl.text.trim().isEmpty
                      ? null
                      : _descriptionCtrl.text.trim(),
                  email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                  taxId: _emptyToNull(_taxIdCtrl.text),
                  logoUrl: logoUrl,
                  websiteUrl: _websiteUrlCtrl.text.trim().isEmpty ? null : _websiteUrlCtrl.text.trim(),
                  instagramUrl: _emptyToNull(_instagramUrlCtrl.text),
                  facebookUrl: _emptyToNull(_facebookUrlCtrl.text),
                  address: _emptyToNull(_addressCtrl.text),
                  city: _emptyToNull(_cityCtrl.text),
                  province: _emptyToNull(_provinceCtrl.text),
                  country: _emptyToNull(_countryCtrl.text),
                  postalCode: _emptyToNull(_postalCodeCtrl.text),
                );
                if (savedSellerId == null || !context.mounted) return;
                if (_logoFile != null) {
                  final uploadedUrl = await notifier.uploadLogo(
                    sellerId: savedSellerId,
                    tenantId: state.fields['tenantId'],
                    file: _logoFile!,
                  );
                  if (uploadedUrl != null) {
                    _logoUrlCtrl.text = uploadedUrl;
                  }
                }
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/organization/sellers');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _emptyToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  void _applyDialCodeFromCountry() {
    final dialCode = _dialCodeForCountry(_countryCtrl.text);
    setState(() {});
    if (dialCode.isEmpty) return;

    final phone = _phoneCtrl.text.trim();
    if (phone.startsWith('+')) return;

    final nextValue = phone.isEmpty ? '$dialCode ' : '$dialCode $phone';
    _phoneCtrl.text = nextValue;
    _phoneCtrl.selection = TextSelection.collapsed(offset: nextValue.length);
  }

  String _dialCodeForCountry(String country) {
    switch (_normalizeCountry(country)) {
      case 'argentina':
      case 'ar':
        return '+54';
      case 'uruguay':
      case 'uy':
        return '+598';
      case 'chile':
      case 'cl':
        return '+56';
      case 'paraguay':
      case 'py':
        return '+595';
      case 'brasil':
      case 'brazil':
      case 'br':
        return '+55';
      case 'bolivia':
      case 'bo':
        return '+591';
      case 'peru':
      case 'pe':
        return '+51';
      case 'colombia':
      case 'co':
        return '+57';
      case 'mexico':
      case 'mx':
        return '+52';
      case 'estados unidos':
      case 'united states':
      case 'usa':
      case 'us':
        return '+1';
      case 'espana':
      case 'spain':
      case 'es':
        return '+34';
      default:
        return '';
    }
  }

  String _normalizeCountry(String country) {
    return country
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

}
