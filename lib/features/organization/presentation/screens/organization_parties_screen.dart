import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/permissions/permissions_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum PartyKind {
  supplier(
    title: 'Proveedores',
    singular: 'Proveedor',
    endpoint: '/v1/suppliers',
    listRoute: '/organization/suppliers',
    permissionPrefix: 'Organization.Suppliers',
    icon: Icons.local_shipping_rounded,
  ),
  customer(
    title: 'Clientes',
    singular: 'Cliente',
    endpoint: '/v1/customers',
    listRoute: '/organization/customers',
    permissionPrefix: 'Organization.Customers',
    icon: Icons.handshake_rounded,
  );

  final String title;
  final String singular;
  final String endpoint;
  final String listRoute;
  final String permissionPrefix;
  final IconData icon;

  const PartyKind({
    required this.title,
    required this.singular,
    required this.endpoint,
    required this.listRoute,
    required this.permissionPrefix,
    required this.icon,
  });
}

class PartyDto {
  final String id;
  final String? tenantId;
  final String? sellerId;
  final String code;
  final String name;
  final String? taxId;
  final String? email;
  final String? phone;
  final String status;
  final bool active;

  const PartyDto({
    required this.id,
    required this.tenantId,
    required this.sellerId,
    required this.code,
    required this.name,
    this.taxId,
    this.email,
    this.phone,
    required this.status,
    required this.active,
  });

  factory PartyDto.fromJson(Map<String, dynamic> json, PartyKind kind) {
    final firstName = json['firstName']?.toString().trim() ?? '';
    final lastName = json['lastName']?.toString().trim() ?? '';
    final businessName = json['businessName']?.toString().trim() ?? '';
    final tradeName = json['tradeName']?.toString().trim() ?? '';
    final personName = [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
    final idKey = kind == PartyKind.supplier ? 'supplierId' : 'customerId';
    return PartyDto(
      id: (json[idKey] ?? json['id'])?.toString() ?? '',
      tenantId: json['tenantId']?.toString(),
      sellerId: json['sellerId']?.toString(),
      code: json['code']?.toString() ?? '',
      name: businessName.isNotEmpty
          ? businessName
          : (tradeName.isNotEmpty ? tradeName : (personName.isNotEmpty ? personName : 'Sin nombre')),
      taxId: json['taxId']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      active: json['active'] != false,
    );
  }
}

class PartiesListNotifier extends ListNotifier<PartyDto> {
  final Dio _dio;
  final PartyKind kind;

  PartiesListNotifier(this._dio, this.kind) : super();

  @override
  Future<PaginatedResponse<PartyDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(kind.endpoint, queryParameters: params.toQueryParams());
    return PaginatedResponse.fromJson(resp.data, (json) => PartyDto.fromJson(json, kind));
  }
}

final partiesListProvider = StateNotifierProvider.autoDispose
    .family<PartiesListNotifier, ListState<PartyDto>, PartyKind>(
  (ref, kind) => PartiesListNotifier(ref.watch(dioProvider), kind),
);

class PartiesListScreen extends ConsumerWidget {
  final PartyKind kind;

  const PartiesListScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(partiesListProvider(kind));
    final notifier = ref.read(partiesListProvider(kind).notifier);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission(['${kind.permissionPrefix}.Create', 'Organization.Admin']);
    final canEdit = perms.hasAnyPermission(['${kind.permissionPrefix}.Edit', 'Organization.Admin']);

    return AppPageScaffold(
      title: kind.title,
      searchHint: 'Buscar ${kind.singular.toLowerCase()}...',
      onSearch: notifier.setSearch,
      floatingActionButton: canCreate
          ? CreateFab(
              label: 'Nuevo ${kind.singular.toLowerCase()}',
              onPressed: () async {
                await context.push('${kind.listRoute}/new');
                notifier.reload();
              },
            )
          : null,
      body: _body(context, state, notifier, canEdit),
    );
  }

  Widget _body(
    BuildContext context,
    ListState<PartyDto> state,
    PartiesListNotifier notifier,
    bool canEdit,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar ${kind.title.toLowerCase()}',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: kind.icon,
        title: 'Sin ${kind.title.toLowerCase()}',
        message: 'No hay registros que coincidan con la búsqueda.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, index) {
            if (index == state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LoadingState(),
              );
            }
            final item = state.items[index];
            return _PartyTile(
              item: item,
              icon: kind.icon,
              canEdit: canEdit,
              onEdit: () async {
                await ctx.push('${kind.listRoute}/${item.id}/edit', extra: item);
                notifier.reload();
              },
            );
          },
        ),
      ),
    );
  }
}

class _PartyTile extends StatelessWidget {
  final PartyDto item;
  final IconData icon;
  final bool canEdit;
  final Future<void> Function() onEdit;

  const _PartyTile({
    required this.item,
    required this.icon,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.code.trim().isNotEmpty) item.code.trim(),
      if ((item.taxId ?? '').trim().isNotEmpty) item.taxId!.trim(),
      if ((item.email ?? '').trim().isNotEmpty) item.email!.trim(),
      if ((item.phone ?? '').trim().isNotEmpty) item.phone!.trim(),
    ];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: canEdit ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.accent, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (parts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        parts.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              StatusBadge(status: item.active ? item.status : 'INACTIVE'),
              if (canEdit)
                IconButton(
                  tooltip: 'Editar',
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: onEdit,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PartyFormScreen extends ConsumerStatefulWidget {
  final PartyKind kind;
  final String? id;

  const PartyFormScreen({super.key, required this.kind, this.id});

  @override
  ConsumerState<PartyFormScreen> createState() => _PartyFormScreenState();
}

class _PartyFormScreenState extends ConsumerState<PartyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantId = TextEditingController();
  final _sellerId = TextEditingController();
  final _code = TextEditingController();
  final _businessName = TextEditingController();
  final _taxId = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _tenantId.dispose();
    _sellerId.dispose();
    _code.dispose();
    _businessName.dispose();
    _taxId.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authNotifierProvider);
    _tenantId.text = auth.tenantId ?? '';
    _sellerId.text = auth.sellerId ?? '';
    if (widget.id == null) {
      setState(() => _loading = false);
      return;
    }
    final dio = ref.read(dioProvider);
    final resp = await dio.get('${widget.kind.endpoint}/${widget.id}');
    final data = Map<String, dynamic>.from(resp.data as Map);
    _tenantId.text = data['tenantId']?.toString() ?? '';
    _sellerId.text = data['sellerId']?.toString() ?? '';
    _code.text = data['code']?.toString() ?? '';
    _businessName.text = data['businessName']?.toString() ?? '';
    _taxId.text = data['taxId']?.toString() ?? '';
    _email.text = data['email']?.toString() ?? '';
    _phone.text = data['phone']?.toString() ?? '';
    _notes.text = data['notes']?.toString() ?? '';
    _active = data['active'] != false;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'tenantId': _tenantId.text.trim(),
      'sellerId': _sellerId.text.trim().isEmpty ? null : _sellerId.text.trim(),
      'code': _code.text.trim(),
      'businessName': _businessName.text.trim(),
      'taxId': _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'status': _active ? 'ACTIVE' : 'INACTIVE',
      'active': _active,
    };
    if (widget.kind == PartyKind.customer) {
      payload.putIfAbsent('firstName', () => null);
      payload.putIfAbsent('lastName', () => null);
    }

    final dio = ref.read(dioProvider);
    if (widget.id == null) {
      await dio.post(widget.kind.endpoint, data: payload);
    } else {
      await dio.put('${widget.kind.endpoint}/${widget.id}', data: payload);
    }
    if (mounted) context.go(widget.kind.listRoute);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.id != null;
    return AppPageScaffold(
      title: '${isEdit ? 'Editar' : 'Nuevo'} ${widget.kind.singular.toLowerCase()}',
      body: _loading
          ? const LoadingState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Form(
                  key: _formKey,
                  child: Wrap(
                    runSpacing: 12,
                    spacing: 12,
                    children: [
                      _field(_tenantId, 'Tenant', required: true),
                      _field(_sellerId, 'Seller'),
                      _field(_code, 'Código', required: true),
                      _field(_businessName, 'Razón social / nombre', required: true),
                      _field(_taxId, 'CUIT / documento'),
                      _field(_email, 'Email'),
                      _field(_phone, 'Teléfono'),
                      SizedBox(
                        width: 360,
                        child: SwitchListTile(
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                          title: const Text('Activo'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      SizedBox(
                        width: 732,
                        child: TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Notas'),
                        ),
                      ),
                      SizedBox(
                        width: 732,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _saving ? null : () => context.go(widget.kind.listRoute),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_rounded),
                              label: const Text('Guardar'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool required = false}) {
    return SizedBox(
      width: 360,
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (value) => (value == null || value.trim().isEmpty) ? 'Requerido' : null
            : null,
      ),
    );
  }
}
