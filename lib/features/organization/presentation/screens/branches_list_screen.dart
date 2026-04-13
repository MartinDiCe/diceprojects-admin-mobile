import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BranchDto {
  final String id;
  final String name;
  final String? address;
  final String status;
  final String? tenantId;
  final String? tenantName;

  const BranchDto({
    required this.id,
    required this.name,
    this.address,
    required this.status,
    this.tenantId,
    this.tenantName,
  });

  factory BranchDto.fromJson(Map<String, dynamic> json) => BranchDto(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        address: json['address'],
        status: json['status'] ?? 'ACTIVE',
        tenantId: json['tenantId']?.toString(),
        tenantName: json['tenantName'],
      );
}

class BranchesListNotifier extends ListNotifier<BranchDto> {
  final Dio _dio;
  final String? tenantId;

  BranchesListNotifier(this._dio, this.tenantId) : super();

  @override
  Future<PaginatedResponse<BranchDto>> fetchPage(PageParams params) async {
    final queryParams = params.toQueryParams();
    if (tenantId != null) queryParams['tenantId'] = tenantId;
    final resp = await _dio.get('/v1/branches', queryParameters: queryParams);
    return PaginatedResponse.fromJson(resp.data, BranchDto.fromJson);
  }
}

final branchesListNotifierProvider = StateNotifierProvider.autoDispose
    .family<BranchesListNotifier, ListState<BranchDto>, String?>(
  (ref, tenantId) =>
      BranchesListNotifier(ref.watch(dioProvider), tenantId),
);

class BranchesListScreen extends ConsumerWidget {
  final String? tenantId;
  const BranchesListScreen({super.key, this.tenantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(branchesListNotifierProvider(tenantId));
    final notifier =
        ref.read(branchesListNotifierProvider(tenantId).notifier);

    return AppPageScaffold(
      title: 'Sucursales',
      searchHint: 'Buscar sucursal…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(ListState<BranchDto> state, BranchesListNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar las sucursales',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.store_outlined,
        title: 'Sin sucursales',
        message: 'No hay sucursales que coincidan.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == state.items.length) {
            return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LoadingState());
          }
          final branch = state.items[i];
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 16,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.store_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.name,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            branch.address ??
                                branch.tenantName ??
                                'Sin dirección',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: branch.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
