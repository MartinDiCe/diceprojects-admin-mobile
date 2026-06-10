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

class _PersonFormState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final Map<String, String?> fields;

  const _PersonFormState({
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.fields = const {},
  });

  _PersonFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? error,
    Map<String, String?>? fields,
  }) =>
      _PersonFormState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        error: error,
        fields: fields ?? this.fields,
      );
}

class PersonFormNotifier extends StateNotifier<_PersonFormState> {
  final Dio _dio;
  final String? personId;

  PersonFormNotifier(this._dio, this.personId)
      : super(const _PersonFormState()) {
    if (personId != null) _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final resp = await _dio.get('/v1/people/$personId');
      final data = resp.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        fields: {
          'firstName': data['firstName'],
          'lastName': data['lastName'],
          'email': data['email'],
          'phone': data['phone'],
          'secondaryPhone': data['secondaryPhone'],
          'documentType': data['documentType'],
          'documentNumber': data['documentNumber'],
          'status': data['status'],
          'countryId': data['countryId'],
          'stateId': data['stateId'],
          'cityId': data['cityId'],
          'street': data['street'],
          'neighborhood': data['neighborhood'],
          'addressComplement': data['addressComplement'],
          'postalCode': data['postalCode'],
          'avatarUrl': data['avatarUrl'],
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> save({
    required String firstName,
    required String lastName,
    required String? email,
    required String? phone,
    required String? secondaryPhone,
    required String? documentType,
    required String? documentNumber,
    required String? status,
    required String? countryId,
    required String? stateId,
    required String? cityId,
    required String? street,
    required String? neighborhood,
    required String? addressComplement,
    required String? postalCode,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final body = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'secondaryPhone': secondaryPhone,
        'documentType': documentType,
        'documentNumber': documentNumber,
        'status': status,
        'countryId': countryId,
        'stateId': stateId,
        'cityId': cityId,
        'street': street,
        'neighborhood': neighborhood,
        'addressComplement': addressComplement,
        'postalCode': postalCode,
      };
      if (personId == null) {
        await _dio.post('/v1/people', data: body);
      } else {
        await _dio.put('/v1/people/$personId', data: body);
      }
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

}

final personFormNotifierProvider = StateNotifierProvider.autoDispose
    .family<PersonFormNotifier, _PersonFormState, String?>(
  (ref, personId) => PersonFormNotifier(ref.watch(dioProvider), personId),
);

class PersonFormScreen extends ConsumerStatefulWidget {
  final String? personId;
  const PersonFormScreen({super.key, this.personId});

  @override
  ConsumerState<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends ConsumerState<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _secondaryPhoneCtrl;
  late final TextEditingController _docTypeCtrl;
  late final TextEditingController _docCtrl;
  late final TextEditingController _statusCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _neighborhoodCtrl;
  late final TextEditingController _addressComplementCtrl;
  late final TextEditingController _postalCodeCtrl;
  late final TextEditingController _avatarCtrl;
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _secondaryPhoneCtrl = TextEditingController();
    _docTypeCtrl = TextEditingController();
    _docCtrl = TextEditingController();
    _statusCtrl = TextEditingController(text: 'ACTIVE');
    _countryCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _streetCtrl = TextEditingController();
    _neighborhoodCtrl = TextEditingController();
    _addressComplementCtrl = TextEditingController();
    _postalCodeCtrl = TextEditingController();
    _avatarCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _secondaryPhoneCtrl.dispose();
    _docTypeCtrl.dispose();
    _docCtrl.dispose();
    _statusCtrl.dispose();
    _countryCtrl.dispose();
    _stateCtrl.dispose();
    _cityCtrl.dispose();
    _streetCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _addressComplementCtrl.dispose();
    _postalCodeCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(personFormNotifierProvider(widget.personId));
    final notifier =
        ref.read(personFormNotifierProvider(widget.personId).notifier);

    if (!_populated && state.fields.isNotEmpty) {
      _firstNameCtrl.text = state.fields['firstName'] ?? '';
      _lastNameCtrl.text = state.fields['lastName'] ?? '';
      _emailCtrl.text = state.fields['email'] ?? '';
      _phoneCtrl.text = state.fields['phone'] ?? '';
      _secondaryPhoneCtrl.text = state.fields['secondaryPhone'] ?? '';
      _docTypeCtrl.text = state.fields['documentType'] ?? '';
      _docCtrl.text = state.fields['documentNumber'] ?? '';
      _statusCtrl.text = state.fields['status'] ?? 'ACTIVE';
      _countryCtrl.text = state.fields['countryId'] ?? '';
      _stateCtrl.text = state.fields['stateId'] ?? '';
      _cityCtrl.text = state.fields['cityId'] ?? '';
      _streetCtrl.text = state.fields['street'] ?? '';
      _neighborhoodCtrl.text = state.fields['neighborhood'] ?? '';
      _addressComplementCtrl.text = state.fields['addressComplement'] ?? '';
      _postalCodeCtrl.text = state.fields['postalCode'] ?? '';
      _avatarCtrl.text = state.fields['avatarUrl'] ?? '';
      _populated = true;
    }

    return AppPageScaffold(
      title: widget.personId == null ? 'Nueva Persona' : 'Editar Persona',
      body: state.isLoading
          ? const LoadingState()
          : state.error != null && state.fields.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () => ref.invalidate(
                      personFormNotifierProvider(widget.personId)))
              : _buildForm(context, state, notifier),
    );
  }

  Widget _buildForm(
    BuildContext context,
    _PersonFormState state,
    PersonFormNotifier notifier,
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
              controller: _firstNameCtrl,
              label: 'Nombre',
              hint: 'Nombre',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _lastNameCtrl,
              label: 'Apellido',
              hint: 'Apellido',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
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
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _secondaryPhoneCtrl,
              label: 'Teléfono secundario',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _docTypeCtrl,
                    label: 'Tipo documento',
                    hint: 'DNI / CUIT',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _docCtrl,
                    label: 'Documento',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _statusCtrl,
              label: 'Estado',
              hint: 'ACTIVE',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _avatarCtrl,
              label: 'Avatar URL',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _streetCtrl,
              label: 'Dirección',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _neighborhoodCtrl,
              label: 'Barrio',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _addressComplementCtrl,
              label: 'Complemento',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _postalCodeCtrl,
              label: 'Código postal',
            ),
            const SizedBox(height: 24),
            AppButton(
              label: widget.personId == null ? 'Crear persona' : 'Guardar',
              isLoading: state.isSaving,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await notifier.save(
                  firstName: _firstNameCtrl.text.trim(),
                  lastName: _lastNameCtrl.text.trim(),
                  email: _emailCtrl.text.trim().isEmpty
                      ? null
                      : _emailCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim().isEmpty
                      ? null
                      : _phoneCtrl.text.trim(),
                  secondaryPhone: _emptyToNull(_secondaryPhoneCtrl.text),
                  documentType: _emptyToNull(_docTypeCtrl.text),
                  documentNumber: _docCtrl.text.trim().isEmpty
                      ? null
                      : _docCtrl.text.trim(),
                  status: _emptyToNull(_statusCtrl.text),
                  countryId: _emptyToNull(_countryCtrl.text),
                  stateId: _emptyToNull(_stateCtrl.text),
                  cityId: _emptyToNull(_cityCtrl.text),
                  street: _emptyToNull(_streetCtrl.text),
                  neighborhood: _emptyToNull(_neighborhoodCtrl.text),
                  addressComplement: _emptyToNull(_addressComplementCtrl.text),
                  postalCode: _emptyToNull(_postalCodeCtrl.text),
                );
                if (!ok || !context.mounted) return;
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/people');
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
