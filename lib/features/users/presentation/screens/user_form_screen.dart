import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─── State & Notifier ────────────────────────────────────────────────────────

class _UserFormState {
  final bool isSaving;
  final String? error;
  const _UserFormState({this.isSaving = false, this.error});
  _UserFormState copyWith({bool? isSaving, String? error}) =>
      _UserFormState(
        isSaving: isSaving ?? this.isSaving,
        error: error,
      );
}

class UserFormNotifier extends StateNotifier<_UserFormState> {
  final Dio _dio;
  UserFormNotifier(this._dio) : super(const _UserFormState());

  /// Creates a user via invitation.
  Future<bool> invite({
    required String email,
    String? firstName,
    String? lastName,
    String? tenantId,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _dio.post('/v1/invitations', data: {
        'email': email,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
        if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
      });
      state = state.copyWith(isSaving: false);
      return true;
    } catch (e) {
      state = state.copyWith(
          isSaving: false, error: ErrorHandler.handle(e).message);
      return false;
    }
  }
}

final userFormNotifierProvider =
    StateNotifierProvider.autoDispose<UserFormNotifier, _UserFormState>(
  (ref) => UserFormNotifier(ref.watch(dioProvider)),
);

// ─── Screen ──────────────────────────────────────────────────────────────────

class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({super.key});

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _tenantIdCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _tenantIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(userFormNotifierProvider.notifier).invite(
          email: _emailCtrl.text.trim(),
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          tenantId: _tenantIdCtrl.text.trim(),
        );
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitación enviada correctamente.')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userFormNotifierProvider);
    return AppPageScaffold(
      title: 'Invitar usuario',
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.error != null)
                ErrorState(message: state.error!, onRetry: null),
              AppTextField(
                label: 'Email *',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                  if (!emailRegex.hasMatch(v.trim())) return 'Email inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Nombre',
                controller: _firstNameCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Apellido',
                controller: _lastNameCtrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Tenant ID (opcional)',
                controller: _tenantIdCtrl,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Enviar invitación',
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
