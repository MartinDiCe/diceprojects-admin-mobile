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
          'name': data['name'],
          'domain': data['domain'],
          'plan': data['plan'],
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> save({
    required String name,
    required String? domain,
    required String? plan,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final body = {'name': name, 'domain': domain, 'plan': plan};
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
  late final TextEditingController _nameCtrl;
  late final TextEditingController _domainCtrl;
  late final TextEditingController _planCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _domainCtrl = TextEditingController();
    _planCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _domainCtrl.dispose();
    _planCtrl.dispose();
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
      _nameCtrl.text = state.fields['name'] ?? '';
      _domainCtrl.text = state.fields['domain'] ?? '';
      _planCtrl.text = state.fields['plan'] ?? '';
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
              controller: _nameCtrl,
              label: 'Nombre',
              hint: 'Nombre de la empresa',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _domainCtrl,
              label: 'Dominio',
              hint: 'ejemplo.com',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _planCtrl,
              label: 'Plan',
              hint: 'FREE, BASIC, PRO…',
            ),
            const SizedBox(height: 24),
            AppButton(
              label: widget.tenantId == null ? 'Crear empresa' : 'Guardar',
              isLoading: state.isSaving,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await notifier.save(
                  name: _nameCtrl.text.trim(),
                  domain: _domainCtrl.text.trim().isEmpty
                      ? null
                      : _domainCtrl.text.trim(),
                  plan: _planCtrl.text.trim().isEmpty
                      ? null
                      : _planCtrl.text.trim(),
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
}
