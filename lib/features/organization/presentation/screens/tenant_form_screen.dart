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

// ────────────────────────────── Form State ──────────────────────────────

class _TenantFormState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final Map<String, String?> fields;

  const _TenantFormState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.fields = const {},
  });

  _TenantFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    Map<String, String?>? fields,
  }) =>
      _TenantFormState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: error,
        fields: fields ?? this.fields,
      );
}

class TenantFormNotifier extends StateNotifier<_TenantFormState> {
  final Dio _dio;
  final String? tenantId;

  TenantFormNotifier(this._dio, this.tenantId) : super(const _TenantFormState()) {
    if (tenantId != null) _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final resp = await _dio.get('/v1/tenants/$tenantId');
      final data = resp.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        fields: {
          'code': data['code'],
          'name': data['name'],
          'taxId': data['taxId'],
          'description': data['description'],
          'logoUrl': data['logoUrl'],
          'websiteUrl': data['websiteUrl'],
          'baseCurrencyCode': data['baseCurrencyCode'],
          'languageCode': data['languageCode'],
          'countryId': data['countryId'],
          'sectorId': data['sectorId'],
          'timezoneId': data['timezoneId'],
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> save({
    required String code,
    required String name,
    required String? taxId,
    required String? description,
    required String? logoUrl,
    required String? websiteUrl,
    required String? baseCurrencyCode,
    required String? languageCode,
    required String? countryId,
    required String? sectorId,
    required String? timezoneId,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final body = {
        'code': code,
        'name': name,
        'taxId': taxId,
        'description': description,
        'logoUrl': logoUrl,
        'websiteUrl': websiteUrl,
        'baseCurrencyCode': baseCurrencyCode,
        'languageCode': languageCode,
        'countryId': countryId,
        'sectorId': sectorId,
        'timezoneId': timezoneId,
      };
      if (tenantId == null) {
        await _dio.post('/v1/tenants', data: body);
      } else {
        await _dio.put('/v1/tenants/$tenantId', data: body);
      }
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

}

final tenantFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<TenantFormNotifier, _TenantFormState, String?>(
  (ref, tenantId) => TenantFormNotifier(ref.watch(dioProvider), tenantId),
);

// ────────────────────────────── Screen ──────────────────────────────

class TenantFormScreen extends ConsumerStatefulWidget {
  final String? tenantId;
  const TenantFormScreen({super.key, this.tenantId});

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _taxIdCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _logoCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _languageCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _sectorCtrl;
  late final TextEditingController _timezoneCtrl;

  @override
  void initState() {
    super.initState();
    _codeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _taxIdCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _logoCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _currencyCtrl = TextEditingController(text: 'ARS');
    _languageCtrl = TextEditingController(text: 'es-AR');
    _countryCtrl = TextEditingController();
    _sectorCtrl = TextEditingController();
    _timezoneCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _taxIdCtrl.dispose();
    _descriptionCtrl.dispose();
    _logoCtrl.dispose();
    _websiteCtrl.dispose();
    _currencyCtrl.dispose();
    _languageCtrl.dispose();
    _countryCtrl.dispose();
    _sectorCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  bool _populated = false;

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(tenantFormNotifierProvider(widget.tenantId));
    final notifier =
        ref.read(tenantFormNotifierProvider(widget.tenantId).notifier);

    if (!_populated && state.fields.isNotEmpty) {
      _codeCtrl.text = state.fields['code'] ?? '';
      _nameCtrl.text = state.fields['name'] ?? '';
      _taxIdCtrl.text = state.fields['taxId'] ?? '';
      _descriptionCtrl.text = state.fields['description'] ?? '';
      _logoCtrl.text = state.fields['logoUrl'] ?? '';
      _websiteCtrl.text = state.fields['websiteUrl'] ?? '';
      _currencyCtrl.text = state.fields['baseCurrencyCode'] ?? 'ARS';
      _languageCtrl.text = state.fields['languageCode'] ?? 'es-AR';
      _countryCtrl.text = state.fields['countryId'] ?? '';
      _sectorCtrl.text = state.fields['sectorId'] ?? '';
      _timezoneCtrl.text = state.fields['timezoneId'] ?? '';
      _populated = true;
    }

    return AppPageScaffold(
      title: widget.tenantId == null ? 'Nueva Empresa' : 'Editar Empresa',
      body: state.isLoading
          ? const LoadingState()
          : state.error != null && state.fields.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () => ref.invalidate(
                      tenantFormNotifierProvider(widget.tenantId)))
              : _buildForm(context, state, notifier),
    );
  }

  Widget _buildForm(
    BuildContext context,
    _TenantFormState state,
    TenantFormNotifier notifier,
  ) {
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
                child: Text(state.error!,
                    style: TextStyle(color: Colors.red.shade700)),
              ),
            AppTextField(
              controller: _codeCtrl,
              label: 'Código',
              hint: 'ALMICO_TEXTIL',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _nameCtrl,
              label: 'Nombre',
              hint: 'Nombre de la empresa',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _taxIdCtrl,
              label: 'CUIT',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _descriptionCtrl,
              label: 'Descripción',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _logoCtrl,
              label: 'Logo URL',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _websiteCtrl,
              label: 'Sitio web',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppTextField(controller: _currencyCtrl, label: 'Moneda')),
                const SizedBox(width: 10),
                Expanded(child: AppTextField(controller: _languageCtrl, label: 'Idioma')),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _countryCtrl,
              label: 'País ID',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _sectorCtrl,
              label: 'Sector ID',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _timezoneCtrl,
              label: 'Timezone ID',
            ),
            const SizedBox(height: 24),
            AppButton(
              label: widget.tenantId == null ? 'Crear empresa' : 'Guardar',
              isLoading: state.isSaving,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await notifier.save(
                  code: _codeCtrl.text.trim(),
                  name: _nameCtrl.text.trim(),
                  taxId: _emptyToNull(_taxIdCtrl.text),
                  description: _emptyToNull(_descriptionCtrl.text),
                  logoUrl: _emptyToNull(_logoCtrl.text),
                  websiteUrl: _emptyToNull(_websiteCtrl.text),
                  baseCurrencyCode: _emptyToNull(_currencyCtrl.text),
                  languageCode: _emptyToNull(_languageCtrl.text),
                  countryId: _emptyToNull(_countryCtrl.text),
                  sectorId: _emptyToNull(_sectorCtrl.text),
                  timezoneId: _emptyToNull(_timezoneCtrl.text),
                );
                if (!ok || !context.mounted) return;
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/admin/tenants');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

}
