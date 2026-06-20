import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_entity_tile.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:app_diceprojects_admin/features/organization/presentation/widgets/tenant_scope_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ────────────────────────────── Model ──────────────────────────────

class StorageConditionDto {
  final String conditionId;
  final String code;
  final String name;
  final String? description;
  final bool active;
  final bool isGlobal;

  const StorageConditionDto({
    required this.conditionId,
    required this.code,
    required this.name,
    this.description,
    required this.active,
    required this.isGlobal,
  });

  factory StorageConditionDto.fromJson(Map<String, dynamic> json) =>
      StorageConditionDto(
        conditionId: (json['conditionId'] ?? json['id'])?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
        isGlobal: json['isGlobal'] == true,
      );

  String get statusCode => active ? 'ACTIVE' : 'INACTIVE';
}

// ────────────────────────────── Notifier ──────────────────────────────

class StorageConditionsNotifier extends ListNotifier<StorageConditionDto> {
  final Dio _dio;
  final String? tenantId;

  StorageConditionsNotifier(this._dio, this.tenantId) : super();

  @override
  Future<PaginatedResponse<StorageConditionDto>> fetchPage(
      PageParams params) async {
    final query = params.toQueryParams();
    query['size'] = 50;
    query['pageSize'] = 50;
    final scopedTenant = tenantId?.trim();
    if (scopedTenant != null && scopedTenant.isNotEmpty) {
      query['companyId'] = scopedTenant;
    }

    final resp = await _dio.get(
      '/v1/storage-conditions',
      queryParameters: query,
    );
    return PaginatedResponse.fromJson(resp.data, StorageConditionDto.fromJson);
  }
}

final selectedStorageConditionsTenantProvider =
    StateProvider.autoDispose<String?>((ref) => null);

final storageConditionsNotifierProvider = StateNotifierProvider.autoDispose
    .family<StorageConditionsNotifier, ListState<StorageConditionDto>, String?>(
  (ref, tenantId) =>
      StorageConditionsNotifier(ref.watch(dioProvider), tenantId),
);

// ────────────────────────────── Screen ──────────────────────────────

class StorageConditionsScreen extends ConsumerWidget {
  const StorageConditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final selectedTenant = ref.watch(selectedStorageConditionsTenantProvider);
    final effectiveTenant = auth.isAdminGlobal ? selectedTenant : auth.tenantId;
    final state = ref.watch(storageConditionsNotifierProvider(effectiveTenant));
    final notifier =
        ref.read(storageConditionsNotifierProvider(effectiveTenant).notifier);

    return AppPageScaffold(
      title: 'Condiciones',
      searchHint: 'Buscar condición…',
      onSearch: notifier.setSearch,
      body: Column(
        children: [
          TenantScopeFilter(
            selectedTenantProvider: selectedStorageConditionsTenantProvider,
          ),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildBody(
    ListState<StorageConditionDto> state,
    StorageConditionsNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las condiciones',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.thermostat_outlined,
        title: 'Sin condiciones',
        message: 'No hay condiciones que coincidan con la búsqueda.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          final c = state.items[i];
          return AppEntityTile(
            icon: Icons.thermostat_rounded,
            title: c.name,
            details: [
              c.code,
              if ((c.description ?? '').trim().isNotEmpty) c.description!,
              if (c.isGlobal) 'Global',
            ],
            status: c.statusCode,
          );
        },
      ),
    );
  }
}
