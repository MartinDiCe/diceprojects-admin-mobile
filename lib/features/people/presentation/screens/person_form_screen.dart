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
          'documentNumber': data['documentNumber'],
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
    required String? documentNumber,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final body = {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'documentNumber': documentNumber,
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
  late final TextEditingController _docCtrl;
  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl = TextEditingController();
    _lastNameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _docCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _docCtrl.dispose();
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
      _docCtrl.text = state.fields['documentNumber'] ?? '';
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
              controller: _docCtrl,
              label: 'Documento',
              hint: 'DNI / Pasaporte',
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
                  documentNumber: _docCtrl.text.trim().isEmpty
                      ? null
                      : _docCtrl.text.trim(),
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
}
