import 'package:app_diceprojects_admin/core/errors/error_handler.dart';
import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class _TenantLookupDto {
  final String id;
  final String name;

  const _TenantLookupDto({required this.id, required this.name});

  factory _TenantLookupDto.fromJson(Map<String, dynamic> json) => _TenantLookupDto(
        id: (json['id'])?.toString() ?? '',
        name: (json['name'])?.toString() ?? '',
      );
}

class _RoleLookupDto {
  final String id;
  final String code;
  final String name;

  const _RoleLookupDto({required this.id, required this.code, required this.name});

  factory _RoleLookupDto.fromJson(Map<String, dynamic> json) => _RoleLookupDto(
        id: (json['id'])?.toString() ?? '',
        code: (json['code'])?.toString() ?? '',
        name: (json['description'] ?? json['name'] ?? json['code'] ?? '').toString(),
      );
}

final _tenantsLookupProvider = FutureProvider.autoDispose<List<_TenantLookupDto>>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get(
      '/v1/tenants',
      queryParameters: const {
        'page': 0,
        'size': 200,
        'pageSize': 200,
      },
    );
    return PaginatedResponse.fromJson(resp.data, _TenantLookupDto.fromJson).items;
  },
);

final _rolesLookupProvider = FutureProvider.autoDispose<List<_RoleLookupDto>>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final resp = await dio.get('/v1/roles');
    return PaginatedResponse.fromJson(resp.data, _RoleLookupDto.fromJson).items;
  },
);

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
    final tenantsAsync = ref.watch(_tenantsLookupProvider);
    final rolesAsync = ref.watch(_rolesLookupProvider);

    return AppPageScaffold(
      title: 'Invitar Usuario',
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
              tenantsAsync.when(
                loading: () => const SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cargando empresas…'),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (tenants) {
                  if (tenants.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    key: ValueKey(_selectedTenantId ?? 'none'),
                    initialValue: _selectedTenantId,
                    decoration: const InputDecoration(
                      labelText: 'Empresa (opcional)',
                    ),
                    items: tenants
                        .map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(
                              t.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedTenantId = v),
                  );
                },
              ),
              const SizedBox(height: 12),
              rolesAsync.when(
                loading: () => const SizedBox(
                  height: 56,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cargando roles…'),
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (roles) {
                  if (roles.isEmpty) return const SizedBox.shrink();
                  return DropdownButtonFormField<String>(
                    key: ValueKey(_selectedRoleId ?? 'none'),
                    initialValue: _selectedRoleId,
                    decoration: const InputDecoration(
                      labelText: 'Rol *',
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    items: roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text(
                              r.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRoleId = v),
                  );
                },
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Invitar Usuario',
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
