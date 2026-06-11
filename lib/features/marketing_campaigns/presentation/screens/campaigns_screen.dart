import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CampaignDto {
  final String id;
  final String name;
  final String status;
  final String? key;
  final String? sellerName;
  final String? startsAt;
  final String? endsAt;

  const CampaignDto({
    required this.id,
    required this.name,
    required this.status,
    this.key,
    this.sellerName,
    this.startsAt,
    this.endsAt,
  });

  factory CampaignDto.fromJson(Map<String, dynamic> json) => CampaignDto(
        id: (json['campaignId'] ?? json['id'])?.toString() ?? '',
        name: (json['name'] ?? json['title'] ?? 'Campaña').toString(),
        status: (json['status'] ?? json['statusCode'] ?? 'ACTIVE').toString(),
        key: (json['frontendKey'] ?? json['campaignKey'] ?? json['key'])
            ?.toString(),
        sellerName: (json['sellerName'] ?? json['sellerBusinessName'])
            ?.toString(),
        startsAt: (json['startsAt'] ?? json['startDate'])?.toString(),
        endsAt: (json['endsAt'] ?? json['endDate'])?.toString(),
      );
}

class CampaignsNotifier extends ListNotifier<CampaignDto> {
  final Dio _dio;
  final AuthState _auth;

  CampaignsNotifier(this._dio, this._auth) : super();

  @override
  Future<PaginatedResponse<CampaignDto>> fetchPage(PageParams params) async {
    final scope = _scopedQuery(_auth);
    if (scope.isEmpty && _auth.isAdminGlobal) {
      return _fetchAcrossTenants(params);
    }
    final response = await _dio.get(
      '/v1/campaigns',
      queryParameters: {
        ...params.toQueryParams(),
        ...scope,
      },
      options: _tenantOptions(_auth, scope['tenantId']?.toString()),
    );
    return PaginatedResponse.fromJson(response.data, CampaignDto.fromJson);
  }

  Future<PaginatedResponse<CampaignDto>> _fetchAcrossTenants(PageParams params) async {
    final tenants = await _dio.get('/v1/tenants', queryParameters: {'page': 0, 'size': 50, 'pageSize': 50});
    final tenantIds = _extractTenantIds(tenants.data);
    final items = <CampaignDto>[];
    for (final tenantId in tenantIds) {
      final response = await _dio.get(
        '/v1/campaigns',
        queryParameters: {
          ...params.toQueryParams(),
          'tenantId': tenantId,
        },
        options: _tenantOptions(_auth, tenantId),
      );
      items.addAll(PaginatedResponse.fromJson(response.data, CampaignDto.fromJson).items);
    }
    return PaginatedResponse(
      items: items,
      totalElements: items.length,
      totalPages: 1,
      currentPage: 0,
      hasMore: false,
    );
  }
}

final campaignsNotifierProvider =
    StateNotifierProvider.autoDispose<CampaignsNotifier,
        ListState<CampaignDto>>(
  (ref) => CampaignsNotifier(ref.watch(dioProvider), ref.watch(authNotifierProvider)),
);

Map<String, dynamic> _scopedQuery(AuthState auth) {
  final params = <String, dynamic>{};
  final tenantId = auth.tenantId?.trim();
  if (tenantId != null && tenantId.isNotEmpty) {
    params['tenantId'] = tenantId;
  }
  final sellerId = auth.sellerId?.trim();
  if (sellerId != null && sellerId.isNotEmpty) {
    params['sellerId'] = sellerId;
  } else if (!auth.isAdminGlobal && auth.sellerIds.length == 1) {
    params['sellerId'] = auth.sellerIds.first;
  }
  return params;
}

Options? _tenantOptions(AuthState auth, String? tenantId) {
  final headers = <String, String>{};
  final tenant = tenantId?.trim();
  if (tenant != null && tenant.isNotEmpty) headers['X-Tenant-Id'] = tenant;
  if (auth.roles.isNotEmpty) headers['X-Roles'] = auth.roles.join(',');
  return headers.isEmpty ? null : Options(headers: headers);
}

List<String> _extractTenantIds(dynamic raw) {
  final list = raw is List
      ? raw
      : raw is Map
          ? ((raw['content'] as List?) ?? (raw['items'] as List?) ?? const [])
          : const [];
  return list
      .whereType<Map>()
      .map((item) => (item['tenantId'] ?? item['companyId'] ?? item['id'] ?? '').toString())
      .where((id) => id.isNotEmpty)
      .toList();
}

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(campaignsNotifierProvider);
    final notifier = ref.read(campaignsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Campañas',
      searchHint: 'Buscar campaña...',
      onSearch: notifier.setSearch,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: notifier.reload,
        ),
      ],
      body: _CampaignsBody(state: state, notifier: notifier),
    );
  }
}

class _CampaignsBody extends StatelessWidget {
  final ListState<CampaignDto> state;
  final CampaignsNotifier notifier;

  const _CampaignsBody({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar campañas',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.campaign_rounded,
        title: 'Sin campañas',
        message: 'No hay campañas para los filtros seleccionados.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LoadingState(),
              );
            }
            final campaign = state.items[index];
            return _CampaignCard(campaign: campaign);
          },
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignDto campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_rounded,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (campaign.key != null) campaign.key!,
                    if (campaign.sellerName != null) campaign.sellerName!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusBadge(status: campaign.status),
        ],
      ),
    );
  }
}
