import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_button.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_entity_tile.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_text_field.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/context/operational_context_provider.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/widgets/tenant_scope_filter.dart';
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
    listRoute: '/partners',
    permissionPrefix: 'Organization.Suppliers',
    icon: Icons.local_shipping_rounded,
  ),
  customer(
    title: 'Clientes',
    singular: 'Cliente',
    endpoint: '/v1/customers',
    listRoute: '/customers',
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
    final personName =
        [firstName, lastName].where((e) => e.isNotEmpty).join(' ');
    final idKey = kind == PartyKind.supplier ? 'supplierId' : 'customerId';
    return PartyDto(
      id: (json[idKey] ?? json['id'])?.toString() ?? '',
      tenantId: json['tenantId']?.toString(),
      sellerId: json['sellerId']?.toString(),
      code: json['code']?.toString() ?? '',
      name: businessName.isNotEmpty
          ? businessName
          : (tradeName.isNotEmpty
              ? tradeName
              : (personName.isNotEmpty ? personName : 'Sin nombre')),
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
  final String? tenantId;
  final String? sellerId;

  PartiesListNotifier(this._dio, this.kind, this.tenantId, this.sellerId)
      : super();

  @override
  Future<PaginatedResponse<PartyDto>> fetchPage(PageParams params) async {
    final scopedTenant = tenantId?.trim();
    if (scopedTenant == null || scopedTenant.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: kind.endpoint),
        message:
            'Seleccioná una empresa para cargar ${kind.title.toLowerCase()}.',
      );
    }
    final query = params.toQueryParams()
      ..['tenantId'] = scopedTenant
      ..['companyId'] = scopedTenant;
    final scopedSeller = sellerId?.trim();
    if (scopedSeller != null && scopedSeller.isNotEmpty) {
      query['sellerId'] = scopedSeller;
    }
    final resp = await _dio.get(
      kind.endpoint,
      queryParameters: query,
      options: tenantScopeOptions(scopedTenant, sellerId: scopedSeller),
    );
    return PaginatedResponse.fromJson(
        resp.data, (json) => PartyDto.fromJson(json, kind));
  }
}

final partiesListProvider = StateNotifierProvider.autoDispose
    .family<PartiesListNotifier, ListState<PartyDto>, _PartiesListArgs>(
  (ref, args) => PartiesListNotifier(
    ref.watch(dioProvider),
    args.kind,
    args.tenantId,
    args.sellerId,
  ),
);

class _PartiesListArgs {
  final PartyKind kind;
  final String? tenantId;
  final String? sellerId;

  const _PartiesListArgs(this.kind, this.tenantId, this.sellerId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PartiesListArgs &&
          other.kind == kind &&
          other.tenantId == tenantId &&
          other.sellerId == sellerId;

  @override
  int get hashCode => Object.hash(kind, tenantId, sellerId);
}

class PartiesListScreen extends ConsumerWidget {
  final PartyKind kind;

  const PartiesListScreen({super.key, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final tenantId = effectiveTenantId(ref);
    final sellerId = effectiveSellerId(ref);
    final mustChooseTenant =
        auth.isAdminGlobal && (tenantId == null || tenantId.isEmpty);
    final perms = ref.watch(permissionsProvider);
    final canCreate = perms.hasAnyPermission(
        ['${kind.permissionPrefix}.Create', 'Organization.Admin']);
    final canEdit = perms.hasAnyPermission(
        ['${kind.permissionPrefix}.Edit', 'Organization.Admin']);

    if (mustChooseTenant) {
      return AppPageScaffold(
        title: kind.title,
        searchHint: 'Buscar ${kind.singular.toLowerCase()}...',
        body: Column(
          children: [
            const _PartyScopeBar(),
            Expanded(
              child: EmptyState(
                icon: Icons.business_rounded,
                title: 'Seleccioná una empresa',
                message:
                    'Elegí una empresa para cargar ${kind.title.toLowerCase()}.',
              ),
            ),
          ],
        ),
      );
    }

    final args = _PartiesListArgs(
      kind,
      tenantId,
      sellerId,
    );
    final state = ref.watch(partiesListProvider(args));
    final notifier = ref.read(partiesListProvider(args).notifier);

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
      body: Column(
        children: [
          if (auth.isAdminGlobal) const _PartyScopeBar(),
          Expanded(child: _body(context, state, notifier, canEdit)),
        ],
      ),
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
                await ctx.push('${kind.listRoute}/${item.id}/edit',
                    extra: item);
                notifier.reload();
              },
            );
          },
        ),
      ),
    );
  }
}

class _PartyScopeBar extends ConsumerWidget {
  const _PartyScopeBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(operationalContextProvider);
    final tenants = ref.watch(tenantScopeOptionsProvider);
    final sellers = ref.watch(sellerScopeOptionsProvider(selected.tenantId));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          tenants.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text(
              'No pudimos cargar empresas.',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            data: (items) => DropdownButtonFormField<String>(
              initialValue: items.any((item) => item.id == selected.tenantId)
                  ? selected.tenantId
                  : null,
              decoration: const InputDecoration(labelText: 'Empresa *'),
              isExpanded: true,
              items: items
                  .map(
                    (tenant) => DropdownMenuItem<String>(
                      value: tenant.id,
                      child: Text(
                        tenant.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                final ok = await ref
                    .read(authNotifierProvider.notifier)
                    .switchTenant(value);
                if (!ok) return;
                ref.read(operationalContextProvider.notifier).setTenant(value);
                ref.invalidate(sellerScopeOptionsProvider);
              },
            ),
          ),
          sellers.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty || selected.tenantId == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DropdownButtonFormField<String>(
                  initialValue:
                      items.any((item) => item.id == selected.sellerId)
                          ? selected.sellerId
                          : null,
                  decoration: const InputDecoration(labelText: 'Vendedor'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Todos los vendedores'),
                    ),
                    ...items.map(
                      (seller) => DropdownMenuItem<String>(
                        value: seller.id,
                        child: Text(
                          seller.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => ref
                      .read(operationalContextProvider.notifier)
                      .setSeller(value),
                ),
              );
            },
          ),
        ],
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

    return AppEntityTile(
      icon: icon,
      title: item.name,
      details: parts,
      status: item.active ? item.status : 'INACTIVE',
      onTap: canEdit ? onEdit : null,
      actions: [
        if (canEdit)
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_rounded, size: 20),
            onPressed: onEdit,
          ),
      ],
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
  String? _error;
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
    try {
      final auth = ref.read(authNotifierProvider);
      _tenantId.text = auth.tenantId ?? '';
      _sellerId.text = auth.sellerId ?? '';
      if (widget.id == null) {
        if (auth.isAdminGlobal) _tenantId.clear();
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
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _partyErrorMessage(error, widget.kind);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos cargar ${widget.kind.singular.toLowerCase()}.';
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAdminGlobal) {
      _tenantId.text = auth.tenantId ?? '';
      _sellerId.text = auth.sellerId ?? '';
    }
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

    try {
      final dio = ref.read(dioProvider);
      if (widget.id == null) {
        await dio.post(widget.kind.endpoint, data: payload);
      } else {
        await dio.put('${widget.kind.endpoint}/${widget.id}', data: payload);
      }
      if (mounted) context.go(widget.kind.listRoute);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _partyErrorMessage(error, widget.kind);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'No pudimos guardar ${widget.kind.singular.toLowerCase()}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.id != null;
    final auth = ref.watch(authNotifierProvider);
    return AppPageScaffold(
      title:
          '${isEdit ? 'Editar' : 'Nuevo'} ${widget.kind.singular.toLowerCase()}',
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(
                  title:
                      'No pudimos abrir ${widget.kind.singular.toLowerCase()}',
                  message: _error!,
                  onRetry: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            runSpacing: 12,
                            spacing: 12,
                            children: [
                              if (auth.isAdminGlobal)
                                SizedBox(
                                  width: 360,
                                  child: _TenantDropdownField(
                                    controller: _tenantId,
                                  ),
                                ),
                              _field(_code, 'Código', required: true),
                              _field(_businessName, 'Razón social / nombre',
                                  required: true),
                              _field(_taxId, 'CUIT / documento'),
                              _field(_email, 'Email',
                                  keyboardType: TextInputType.emailAddress),
                              _field(_phone, 'Teléfono',
                                  keyboardType: TextInputType.phone),
                              SizedBox(
                                width: 360,
                                child: SwitchListTile(
                                  value: _active,
                                  onChanged: (value) =>
                                      setState(() => _active = value),
                                  title: const Text('Activo'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              SizedBox(
                                width: 732,
                                child: AppTextField(
                                  controller: _notes,
                                  maxLines: 3,
                                  label: 'Notas',
                                ),
                              ),
                            ],
                          ),
                          if (widget.id != null) ...[
                            const SizedBox(height: 20),
                            _PartyRelationsSection(
                                kind: widget.kind, partyId: widget.id!),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AppButton.secondary(
                                label: 'Cancelar',
                                icon: Icons.close_rounded,
                                onPressed: _saving
                                    ? null
                                    : () => context.go(widget.kind.listRoute),
                              ),
                              const SizedBox(width: 8),
                              AppButton(
                                label: 'Guardar',
                                icon: Icons.save_rounded,
                                isLoading: _saving,
                                onPressed: _save,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
  }) {
    return SizedBox(
      width: 360,
      child: AppTextField(
        controller: controller,
        label: label,
        keyboardType: keyboardType,
        validator: required
            ? (value) =>
                (value == null || value.trim().isEmpty) ? 'Requerido' : null
            : null,
      ),
    );
  }
}

String _partyErrorMessage(DioException error, PartyKind kind) {
  final status = error.response?.statusCode;
  if (status == 404) {
    return 'La ruta de ${kind.title.toLowerCase()} no está disponible en la API publicada. Revisá que el gateway tenga activo /api${kind.endpoint}.';
  }
  if (status == 403) {
    return 'No tenés permisos suficientes para operar ${kind.title.toLowerCase()}.';
  }
  if (status == 400) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return 'Los datos enviados no son válidos.';
  }
  final data = error.response?.data;
  if (data is Map && data['detail'] != null) {
    return data['detail'].toString();
  }
  return error.message ?? 'No pudimos operar ${kind.title.toLowerCase()}.';
}

final _partyContactsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _PartyRelationKey>((ref, key) async {
  final response = await ref
      .watch(dioProvider)
      .get('${key.kind.endpoint}/${key.partyId}/contacts');
  return _relationList(response.data);
});

final _partyAddressesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, _PartyRelationKey>((ref, key) async {
  final response = await ref
      .watch(dioProvider)
      .get('${key.kind.endpoint}/${key.partyId}/addresses');
  return _relationList(response.data);
});

class _PartyRelationsSection extends ConsumerWidget {
  final PartyKind kind;
  final String partyId;

  const _PartyRelationsSection({required this.kind, required this.partyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = _PartyRelationKey(kind, partyId);
    final contacts = ref.watch(_partyContactsProvider(key));
    final addresses = ref.watch(_partyAddressesProvider(key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RelationHeader(
          title: 'Contactos',
          onAdd: () async {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => _ContactSheet(kind: kind, partyId: partyId),
            );
            ref.invalidate(_partyContactsProvider(key));
          },
        ),
        contacts.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('No se pudieron cargar contactos.'),
          data: (items) => _RelationList(
            items: items,
            icon: Icons.person_outline_rounded,
            empty: 'Sin contactos cargados.',
            titleOf: (item) => [item['name'], item['lastName']]
                .where((value) =>
                    value != null && value.toString().trim().isNotEmpty)
                .join(' '),
            subtitleOf: (item) => [item['role'], item['email'], item['phone']]
                .where((value) =>
                    value != null && value.toString().trim().isNotEmpty)
                .join(' · '),
            onDelete: (item) async {
              final id =
                  (item['supplierContactId'] ?? item['customerContactId'])
                      ?.toString();
              if (id == null || id.isEmpty) return;
              await ref
                  .read(dioProvider)
                  .patch('${kind.endpoint}/$partyId/contacts/$id/delete');
              ref.invalidate(_partyContactsProvider(key));
            },
          ),
        ),
        const SizedBox(height: 18),
        _RelationHeader(
          title: 'Direcciones',
          onAdd: () async {
            await showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => _AddressSheet(kind: kind, partyId: partyId),
            );
            ref.invalidate(_partyAddressesProvider(key));
          },
        ),
        addresses.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('No se pudieron cargar direcciones.'),
          data: (items) => _RelationList(
            items: items,
            icon: Icons.location_on_outlined,
            empty: 'Sin direcciones cargadas.',
            titleOf: (item) =>
                '${item['type'] ?? 'Direccion'} · ${item['addressLine1'] ?? ''}',
            subtitleOf: (item) => [
              item['city'],
              item['province'],
              item['country'],
              item['postalCode']
            ]
                .where((value) =>
                    value != null && value.toString().trim().isNotEmpty)
                .join(' · '),
            onDelete: (item) async {
              final id =
                  (item['supplierAddressId'] ?? item['customerAddressId'])
                      ?.toString();
              if (id == null || id.isEmpty) return;
              await ref
                  .read(dioProvider)
                  .patch('${kind.endpoint}/$partyId/addresses/$id/delete');
              ref.invalidate(_partyAddressesProvider(key));
            },
          ),
        ),
      ],
    );
  }
}

class _TenantDropdownField extends ConsumerWidget {
  final TextEditingController controller;

  const _TenantDropdownField({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenants = ref.watch(tenantScopeOptionsProvider);
    return tenants.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => AppTextField(
        controller: controller,
        label: 'Empresa',
        validator: _requiredField,
      ),
      data: (items) {
        final current = controller.text.trim();
        final value = items.any((item) => item.id == current) ? current : null;
        return DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Empresa *'),
          items: items
              .map(
                (tenant) => DropdownMenuItem<String>(
                  value: tenant.id,
                  child: Text(
                    tenant.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          validator: _requiredField,
          onChanged: (value) {
            controller.text = value ?? '';
          },
        );
      },
    );
  }
}

class _ContactSheet extends ConsumerStatefulWidget {
  final PartyKind kind;
  final String partyId;

  const _ContactSheet({required this.kind, required this.partyId});

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _role = TextEditingController();
  bool _primary = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Nuevo contacto',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            AppTextField(
                label: 'Nombre *', controller: _name, validator: _required),
            const SizedBox(height: 10),
            AppTextField(label: 'Apellido', controller: _lastName),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Email',
                controller: _email,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Telefono',
                controller: _phone,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            AppTextField(label: 'Rol', controller: _role),
            SwitchListTile(
              value: _primary,
              onChanged:
                  _saving ? null : (value) => setState(() => _primary = value),
              title: const Text('Contacto principal'),
              contentPadding: EdgeInsets.zero,
            ),
            AppButton(
              label: 'Guardar contacto',
              icon: Icons.save_rounded,
              isLoading: _saving,
              fullWidth: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post(
        '${widget.kind.endpoint}/${widget.partyId}/contacts',
        data: {
          'name': _name.text.trim(),
          'lastName': _emptyToNull(_lastName.text),
          'email': _emptyToNull(_email.text),
          'phone': _emptyToNull(_phone.text),
          'role': _emptyToNull(_role.text),
          'isPrimary': _primary,
        },
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AddressSheet extends ConsumerStatefulWidget {
  final PartyKind kind;
  final String partyId;

  const _AddressSheet({required this.kind, required this.partyId});

  @override
  ConsumerState<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends ConsumerState<_AddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController(text: 'COMERCIAL');
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _country = TextEditingController(text: 'Argentina');
  final _postalCode = TextEditingController();
  bool _default = false;
  bool _saving = false;

  @override
  void dispose() {
    _type.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _city.dispose();
    _province.dispose();
    _country.dispose();
    _postalCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.50,
      maxChildSize: 0.94,
      builder: (_, controller) => Form(
        key: _formKey,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text('Nueva direccion',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type.text,
              decoration: const InputDecoration(labelText: 'Tipo *'),
              items: const [
                DropdownMenuItem(value: 'COMERCIAL', child: Text('Comercial')),
                DropdownMenuItem(
                    value: 'FACTURACION', child: Text('Facturacion')),
                DropdownMenuItem(value: 'ENTREGA', child: Text('Entrega')),
              ],
              onChanged:
                  _saving ? null : (value) => _type.text = value ?? 'COMERCIAL',
            ),
            const SizedBox(height: 10),
            AppTextField(
                label: 'Direccion *',
                controller: _addressLine1,
                validator: _required),
            const SizedBox(height: 10),
            AppTextField(label: 'Detalle', controller: _addressLine2),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: AppTextField(label: 'Ciudad', controller: _city)),
                const SizedBox(width: 10),
                Expanded(
                    child: AppTextField(
                        label: 'Provincia', controller: _province)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: AppTextField(label: 'Pais', controller: _country)),
                const SizedBox(width: 10),
                Expanded(
                    child: AppTextField(label: 'CP', controller: _postalCode)),
              ],
            ),
            SwitchListTile(
              value: _default,
              onChanged:
                  _saving ? null : (value) => setState(() => _default = value),
              title: const Text('Direccion principal'),
              contentPadding: EdgeInsets.zero,
            ),
            AppButton(
              label: 'Guardar direccion',
              icon: Icons.save_rounded,
              isLoading: _saving,
              fullWidth: true,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Requerido' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).post(
        '${widget.kind.endpoint}/${widget.partyId}/addresses',
        data: {
          'type': _type.text.trim(),
          'addressLine1': _addressLine1.text.trim(),
          'addressLine2': _emptyToNull(_addressLine2.text),
          'city': _emptyToNull(_city.text),
          'province': _emptyToNull(_province.text),
          'country': _emptyToNull(_country.text),
          'postalCode': _emptyToNull(_postalCode.text),
          'isDefault': _default,
        },
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RelationHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;

  const _RelationHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900))),
        AppButton.secondary(
            label: 'Agregar', icon: Icons.add_rounded, onPressed: onAdd),
      ],
    );
  }
}

class _RelationList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final IconData icon;
  final String empty;
  final String Function(Map<String, dynamic>) titleOf;
  final String Function(Map<String, dynamic>) subtitleOf;
  final Future<void> Function(Map<String, dynamic>) onDelete;

  const _RelationList({
    required this.items,
    required this.icon,
    required this.empty,
    required this.titleOf,
    required this.subtitleOf,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(empty, style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      children: items
          .map((item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: AppColors.accent),
                title: Text(titleOf(item),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(subtitleOf(item),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => onDelete(item),
                ),
              ))
          .toList(),
    );
  }
}

class _PartyRelationKey {
  final PartyKind kind;
  final String partyId;

  const _PartyRelationKey(this.kind, this.partyId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _PartyRelationKey &&
          other.kind == kind &&
          other.partyId == partyId;

  @override
  int get hashCode => Object.hash(kind, partyId);
}

List<Map<String, dynamic>> _relationList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String? _emptyToNull(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String? _requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Requerido' : null;
