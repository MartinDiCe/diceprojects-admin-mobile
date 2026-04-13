import 'dart:developer';

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

// ─── State ─────────────────────────────────────────────────────────────────
class _ProfileState {
  final bool isLoading;
  final bool isSaving;
  final bool isChangingPassword;
  final String? error;
  final String? successMsg;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String street;
  final bool profileExists;

  const _ProfileState({
    this.isLoading = false,
    this.isSaving = false,
    this.isChangingPassword = false,
    this.error,
    this.successMsg,
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.street = '',
    this.profileExists = true,
  });

  _ProfileState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isChangingPassword,
    String? error,
    bool clearError = false,
    String? successMsg,
    bool clearSuccess = false,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? street,
    bool? profileExists,
  }) => _ProfileState(
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    isChangingPassword: isChangingPassword ?? this.isChangingPassword,
    error: clearError ? null : (error ?? this.error),
    successMsg: clearSuccess ? null : (successMsg ?? this.successMsg),
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    street: street ?? this.street,
    profileExists: profileExists ?? this.profileExists,
  );
}

class _ProfileNotifier extends StateNotifier<_ProfileState> {
  final Dio _dio;
  _ProfileNotifier(this._dio) : super(const _ProfileState(isLoading: true)) {
    _load();
  }

  Future<void> _load() async {
    try {
      // Try to get the current user profile from people service
      final resp = await _dio.get('/v1/people/me');
      final d = resp.data as Map<String, dynamic>;
      state = state.copyWith(
        isLoading: false,
        profileExists: true,
        firstName: d['firstName']?.toString() ?? '',
        lastName: d['lastName']?.toString() ?? '',
        email: d['email']?.toString() ?? '',
        phone: d['phone']?.toString() ?? d['phoneNumber']?.toString() ?? '',
        street: d['street']?.toString() ?? '',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Profile doesn't exist yet — show empty form with hint
        state = state.copyWith(isLoading: false, profileExists: false, clearError: true);
      } else {
        state = state.copyWith(isLoading: false, clearError: true);
      }
    } catch (e) {
      // Network or unknown error — just show empty form
      state = state.copyWith(isLoading: false, clearError: true);
    }
  }

  Future<bool> saveProfile({
    required String firstName,
    required String lastName,
    required String phone,
    required String street,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true, clearSuccess: true);
    try {
      await _dio.put('/v1/people/me', data: {
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (street.trim().isNotEmpty) 'street': street.trim(),
      });
      state = state.copyWith(
        isSaving: false,
        profileExists: true,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        phone: phone.trim(),
        street: street.trim(),
        successMsg: 'Perfil actualizado correctamente',
      );
      return true;
    } catch (e) {
      log('saveProfile error: $e');
      state = state.copyWith(isSaving: false, error: ErrorHandler.handle(e).message);
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isChangingPassword: true, clearError: true, clearSuccess: true);
    try {
      await _dio.post('/v1/auth/change-password', data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      state = state.copyWith(isChangingPassword: false, successMsg: 'Contraseña actualizada correctamente');
      return true;
    } catch (e) {
      log('changePassword error: $e');
      state = state.copyWith(isChangingPassword: false, error: ErrorHandler.handle(e).message);
      return false;
    }
  }
}

final _profileProvider = StateNotifierProvider.autoDispose<_ProfileNotifier, _ProfileState>(
  (ref) => _ProfileNotifier(ref.watch(dioProvider)),
);

// ─── Screen ────────────────────────────────────────────────────────────────
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _firstName, _lastName, _phone, _address;
  late final TextEditingController _currentPwd, _newPwd, _confirmPwd;
  bool _populated = false;
  bool _showCurrent = false, _showNew = false, _showConfirm = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _phone = TextEditingController();
    _address = TextEditingController();
    _currentPwd = TextEditingController();
    _newPwd = TextEditingController();
    _confirmPwd = TextEditingController();
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_firstName, _lastName, _phone, _address, _currentPwd, _newPwd, _confirmPwd]) c.dispose();
    super.dispose();
  }

  void _populate(_ProfileState s) {
    if (_populated) return;
    _firstName.text = s.firstName;
    _lastName.text = s.lastName;
    _phone.text = s.phone;
    _address.text = s.street;
    _populated = true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final s = ref.watch(_profileProvider);
    if (!_populated && !s.isLoading) _populate(s);

    final username = auth.username ?? 'Usuario';
    final initials = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppPageScaffold(
      title: 'Mi Perfil',
      body: s.isLoading
          ? const LoadingState()
          : Column(children: [
              // Avatar header
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                child: Column(children: [
                  Stack(children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.accentLight,
                      child: Text(initials, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.accent)),
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: isDark ? AppColors.surface : Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(username, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  if (auth.tenantId != null) ...[
                    const SizedBox(height: 2),
                    Text(auth.isAdminGlobal ? 'Admin Global' : 'Tenant: ${auth.tenantId}',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ]),
              ),

              // Tabs
              TabBar(
                controller: _tabs,
                tabs: const [Tab(text: 'Datos personales'), Tab(text: 'Contraseña')],
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.accent,
              ),

              if (s.error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.error.withValues(alpha: 0.4))),
                  child: Text(s.error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              if (!s.profileExists && s.error == null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.accentLight.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(10)),
                  child: const Text('Tu perfil aún no fue creado. Completá tus datos y guardá para configurarlo.', style: TextStyle(fontSize: 13)),
                ),
              if (s.successMsg != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.successLight, borderRadius: BorderRadius.circular(10)),
                  child: Text(s.successMsg!, style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 13)),
                ),

              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    // Tab 1: Datos personales
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                      children: [
                        AppTextField(controller: _firstName, label: 'Nombre *', hint: 'Tu nombre'),
                        const SizedBox(height: 14),
                        AppTextField(controller: _lastName, label: 'Apellido *', hint: 'Tu apellido'),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _phone, label: 'Teléfono', hint: '+54 11 1234-5678',
                          keyboardType: TextInputType.phone,
                          helperText: 'Opcional. Solo para contacto interno.',
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _address, label: 'Dirección', hint: 'Tu dirección',
                          maxLines: 2,
                          helperText: 'Opcional.',
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: s.isSaving ? 'Guardando…' : 'Guardar cambios',
                          onPressed: s.isSaving ? null : () async {
                            if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nombre y apellido son obligatorios')));
                              return;
                            }
                            await ref.read(_profileProvider.notifier).saveProfile(
                              firstName: _firstName.text,
                              lastName: _lastName.text,
                              phone: _phone.text,
                              street: _address.text,
                            );
                          },
                        ),
                      ],
                    ),

                    // Tab 2: Cambiar contraseña
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
                      children: [
                        Text(
                          'Cambiá tu contraseña de acceso.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        AppTextField(
                          controller: _currentPwd,
                          label: 'Contraseña actual *',
                          hint: '••••••••',
                          obscureText: !_showCurrent,
                          suffixIcon: IconButton(
                            icon: Icon(_showCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () => setState(() => _showCurrent = !_showCurrent),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _newPwd,
                          label: 'Nueva contraseña *',
                          hint: '••••••••',
                          obscureText: !_showNew,
                          helperText: 'Mínimo 8 caracteres.',
                          suffixIcon: IconButton(
                            icon: Icon(_showNew ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () => setState(() => _showNew = !_showNew),
                          ),
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: _confirmPwd,
                          label: 'Confirmar contraseña *',
                          hint: '••••••••',
                          obscureText: !_showConfirm,
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.textMuted, size: 20),
                            onPressed: () => setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                        const SizedBox(height: 24),
                        AppButton(
                          label: s.isChangingPassword ? 'Cambiando…' : 'Cambiar contraseña',
                          onPressed: s.isChangingPassword ? null : () async {
                            if (_currentPwd.text.isEmpty || _newPwd.text.isEmpty || _confirmPwd.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completá todos los campos')));
                              return;
                            }
                            if (_newPwd.text != _confirmPwd.text) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
                              return;
                            }
                            if (_newPwd.text.length < 8) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La nueva contraseña debe tener al menos 8 caracteres')));
                              return;
                            }
                            final ok = await ref.read(_profileProvider.notifier).changePassword(
                              currentPassword: _currentPwd.text,
                              newPassword: _newPwd.text,
                            );
                            if (ok) {
                              _currentPwd.clear(); _newPwd.clear(); _confirmPwd.clear();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
    );
  }
}
