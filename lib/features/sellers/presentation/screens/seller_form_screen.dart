import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/features/sellers/presentation/screens/sellers_list_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        'name': seller.name,
        'description': seller.description,
        'email': seller.email,
        'phone': seller.phone,
        'logoUrl': seller.logoUrl,
        'websiteUrl': seller.websiteUrl,
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

  Future<bool> save({
    required String? sellerCode,
    required String name,
    required String? description,
    required String? email,
    required String? phone,
    required String? logoUrl,
    required String? websiteUrl,
  }) async {
    state = state.copyWith(isSaving: true);
    try {
      final body = {
        if (sellerId == null) 'sellerCode': sellerCode,
        'name': name,
        'description': description,
        'email': email,
        'phone': phone,
        'logoUrl': logoUrl,
        'websiteUrl': websiteUrl,
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
  late final TextEditingController _logoUrlCtrl;
  late final TextEditingController _websiteUrlCtrl;

  bool _populated = false;

  @override
  void initState() {
    super.initState();
    _sellerCodeCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _logoUrlCtrl = TextEditingController();
    _websiteUrlCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _sellerCodeCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _logoUrlCtrl.dispose();
    _websiteUrlCtrl.dispose();
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
      _logoUrlCtrl.text = state.fields['logoUrl'] ?? '';
      _websiteUrlCtrl.text = state.fields['websiteUrl'] ?? '';
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
            const SizedBox(height: 24),
            AppButton(
              label: isCreate ? 'Crear vendedor' : 'Guardar',
              isLoading: state.isSaving,
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final ok = await notifier.save(
                  sellerCode: isCreate ? _sellerCodeCtrl.text.trim() : null,
                  name: _nameCtrl.text.trim(),
                  description: _descriptionCtrl.text.trim().isEmpty
                      ? null
                      : _descriptionCtrl.text.trim(),
                  email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                  logoUrl: _logoUrlCtrl.text.trim().isEmpty ? null : _logoUrlCtrl.text.trim(),
                  websiteUrl: _websiteUrlCtrl.text.trim().isEmpty ? null : _websiteUrlCtrl.text.trim(),
                );
                if (!ok || !context.mounted) return;
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
}
