import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantScopeOption {
  final String id;
  final String label;

  const TenantScopeOption({
    required this.id,
    required this.label,
  });
}

class SellerScopeOption {
  final String id;
  final String label;
  final String? tenantId;

  const SellerScopeOption({
    required this.id,
    required this.label,
    this.tenantId,
  });
}

final tenantScopeOptionsProvider =
    FutureProvider.autoDispose<List<TenantScopeOption>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final tenantId = auth.tenantId?.trim();

  if (!auth.isAdminGlobal) {
    if (tenantId == null || tenantId.isEmpty) return const [];
    return [TenantScopeOption(id: tenantId, label: tenantId)];
  }

  final dio = ref.watch(dioProvider);
  final response = await dio.get('/v1/tenants');
  final raw = response.data;
  final rows = raw is List
      ? raw
      : raw is Map
          ? (raw['content'] as List? ?? raw['items'] as List? ?? const [])
          : const [];

  return rows
      .whereType<Map>()
      .map((item) {
        final id = (item['tenantId'] ?? item['id'])?.toString() ?? '';
        final code = item['code']?.toString() ?? '';
        final name = item['name']?.toString() ?? id;
        final active = item['active'] != false;
        if (id.trim().isEmpty || !active) return null;
        final label =
            [code, name].where((v) => v.trim().isNotEmpty).join(' - ');
        return TenantScopeOption(id: id, label: label.isEmpty ? id : label);
      })
      .whereType<TenantScopeOption>()
      .toList();
});

Map<String, String> tenantScopeHeaders(String? tenantId) {
  final normalized = tenantId?.trim();
  if (normalized == null || normalized.isEmpty) return const {};
  return {
    'X-Company-Id': normalized,
    'X-Tenant-Id': normalized,
  };
}

Map<String, String> tenantSellerScopeHeaders(
    String? tenantId, String? sellerId) {
  final headers = Map<String, String>.from(tenantScopeHeaders(tenantId));
  final normalizedSeller = sellerId?.trim();
  if (normalizedSeller != null && normalizedSeller.isNotEmpty) {
    headers['X-Seller-Id'] = normalizedSeller;
  }
  return headers;
}

Options tenantScopeOptions(String? tenantId, {String? sellerId}) {
  return Options(headers: tenantSellerScopeHeaders(tenantId, sellerId));
}

final sellerScopeOptionsProvider = FutureProvider.autoDispose
    .family<List<SellerScopeOption>, String?>((ref, tenantId) async {
  final auth = ref.watch(authNotifierProvider);
  final scopedTenant = tenantId?.trim();
  if (scopedTenant == null || scopedTenant.isEmpty) return const [];

  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/v1/sellers',
    queryParameters: {
      'page': 0,
      'size': 200,
      'pageSize': 200,
      'active': true,
      'tenantId': scopedTenant,
    },
  );

  final raw = response.data;
  final rows = raw is List
      ? raw
      : raw is Map
          ? (raw['content'] as List? ?? raw['items'] as List? ?? const [])
          : const [];

  final allowed = <String>{
    if ((auth.sellerId ?? '').trim().isNotEmpty) auth.sellerId!.trim(),
    ...auth.sellerIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
  };

  final all = rows
      .whereType<Map>()
      .map((item) {
        final id = (item['sellerId'] ?? item['id'])?.toString() ?? '';
        final code = (item['sellerCode'] ?? item['code'])?.toString() ?? '';
        final name =
            (item['name'] ?? item['businessName'] ?? code)?.toString() ?? id;
        final rowTenant = (item['tenantId'] ?? item['companyId'])?.toString();
        final active = item['active'] != false;
        if (id.trim().isEmpty || !active) return null;
        if (rowTenant != null &&
            rowTenant.trim().isNotEmpty &&
            rowTenant.trim() != scopedTenant) {
          return null;
        }
        if (!auth.isAdminGlobal &&
            allowed.isNotEmpty &&
            !allowed.contains(id)) {
          return null;
        }
        final label =
            [code, name].where((v) => v.trim().isNotEmpty).join(' - ');
        return SellerScopeOption(
            id: id, label: label.isEmpty ? id : label, tenantId: rowTenant);
      })
      .whereType<SellerScopeOption>()
      .toList();

  return all;
});

class TenantScopeFilter extends ConsumerWidget {
  final AutoDisposeStateProvider<String?> selectedTenantProvider;
  final bool allowAllForGlobal;

  const TenantScopeFilter({
    super.key,
    required this.selectedTenantProvider,
    this.allowAllForGlobal = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final selected = ref.watch(selectedTenantProvider);
    final optionsAsync = ref.watch(tenantScopeOptionsProvider);

    return optionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (options) {
        if (!auth.isAdminGlobal && options.length <= 1) {
          final only = options.isNotEmpty ? options.first.id : null;
          if (only != null && selected != only) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTenantProvider.notifier).state = only;
            });
          }
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selected?.trim().isEmpty == true ? null : selected,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                  hint: const Text('Empresa'),
                  items: [
                    if (auth.isAdminGlobal && allowAllForGlobal)
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas las empresas'),
                      ),
                    ...options.map(
                      (tenant) => DropdownMenuItem<String?>(
                        value: tenant.id,
                        child: Text(
                          tenant.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    ref.read(selectedTenantProvider.notifier).state = value;
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SellerScopeFilter extends ConsumerWidget {
  final AutoDisposeStateProvider<String?> selectedSellerProvider;
  final String? tenantId;
  final bool allowAll;

  const SellerScopeFilter({
    super.key,
    required this.selectedSellerProvider,
    required this.tenantId,
    this.allowAll = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedSellerProvider);
    final sellersAsync = ref.watch(sellerScopeOptionsProvider(tenantId));

    return sellersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sellers) {
        if ((tenantId ?? '').trim().isEmpty) return const SizedBox.shrink();
        if (sellers.length == 1 && selected != sellers.first.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(selectedSellerProvider.notifier).state = sellers.first.id;
          });
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: selected?.trim().isEmpty == true ? null : selected,
                  isExpanded: true,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                  hint: const Text('Seller'),
                  items: [
                    if (allowAll)
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todos los sellers'),
                      ),
                    ...sellers.map(
                      (seller) => DropdownMenuItem<String?>(
                        value: seller.id,
                        child: Text(
                          seller.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    ref.read(selectedSellerProvider.notifier).state = value;
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
