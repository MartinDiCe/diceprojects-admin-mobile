import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ─── DTOs para dropdowns ──────────────────────────────────────────────────────

class _TenantOption {
  final String id;
  final String name;
  const _TenantOption({required this.id, required this.name});
  factory _TenantOption.fromJson(Map<String, dynamic> j) => _TenantOption(
        id: (j['tenantId'] ?? j['id'])?.toString() ?? '',
        name: (j['name'] ?? j['companyName'] ?? j['tenantId'])?.toString() ?? '',
      );
}

class _RoleOption {
  final String id;
  final String name;
  final String code;
  const _RoleOption({required this.id, required this.name, required this.code});
  factory _RoleOption.fromJson(Map<String, dynamic> j) => _RoleOption(
        id: (j['roleId'] ?? j['id'])?.toString() ?? '',
        name: (j['name'] ?? j['code'])?.toString() ?? '',
        code: (j['code'])?.toString() ?? '',
      );
}

// ─── Providers para listas de selección ──────────────────────────────────────

final _tenantsForFormProvider =
    FutureProvider.autoDispose<List<_TenantOption>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('/v1/tenants');
  final raw = resp.data;
  final list = raw is List ? raw : (raw['content'] as List? ?? []);
  return list
      .map((e) => _TenantOption.fromJson(e as Map<String, dynamic>))
      .where((t) => t.id.isNotEmpty)
      .toList();
});

final _rolesForFormProvider =
    FutureProvider.autoDispose<List<_RoleOption>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get('/v1/roles');
  final raw = resp.data;
  final list = raw is List ? raw : (raw['content'] as List? ?? []);
  return list
      .map((e) => _RoleOption.fromJson(e as Map<String, dynamic>))
      .where((r) => r.id.isNotEmpty)
      .toList();
});

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
    String? roleId,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _dio.post('/v1/invitations', data: {
        'email': email,
        if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
        if (tenantId != null && tenantId.isNotEmpty) 'tenantId': tenantId,
        if (roleId != null && roleId.isNotEmpty) 'roleId': roleId,
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
  String? _selectedTenantId;
  String? _selectedRoleId;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(userFormNotifierProvider.notifier).invite(
          email: _emailCtrl.text.trim(),
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          tenantId: _selectedTenantId,
          roleId: _selectedRoleId,
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
    final tenantsAsync = ref.watch(_tenantsForFormProvider);
    final rolesAsync = ref.watch(_rolesForFormProvider);

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
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
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
              // ── Dropdown de Empresa ──────────────────────────────────────
              tenantsAsync.when(
                loading: () => const SizedBox(
                  height: 56,
                  child: Center(child: LoadingState()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (tenants) => DropdownButtonFormField<String>(
                  key: ValueKey(_selectedTenantId),
                  decoration: InputDecoration(
                    labelText: 'Empresa (opcional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  initialValue: _selectedTenantId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin empresa asignada'),
                    ),
                    ...tenants.map((t) => DropdownMenuItem<String>(
                          value: t.id,
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedTenantId = v),
                ),
              ),
              const SizedBox(height: 12),
              // ── Dropdown de Rol ──────────────────────────────────────────
              rolesAsync.when(
                loading: () => const SizedBox(
                  height: 56,
                  child: Center(child: LoadingState()),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (roles) => DropdownButtonFormField<String>(
                  key: ValueKey(_selectedRoleId),
                  decoration: InputDecoration(
                    labelText: 'Rol (opcional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                  ),
                  initialValue: _selectedRoleId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin rol asignado'),
                    ),
                    ...roles.map((r) => DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(
                            r.name.isNotEmpty ? r.name : r.code,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedRoleId = v),
                ),
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
