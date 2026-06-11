import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DestacadoDto {
  final String id;
  final String title;
  final String? sku;
  final String? description;
  final String status;
  final int? order;
  final int views;
  final int likes;
  final String? imageUrl;

  const DestacadoDto({
    required this.id,
    required this.title,
    this.sku,
    this.description,
    required this.status,
    this.order,
    this.views = 0,
    this.likes = 0,
    this.imageUrl,
  });

  factory DestacadoDto.fromJson(Map<String, dynamic> json) => DestacadoDto(
        id: (json['productId'] ?? json['id'])?.toString() ?? '',
        title: (json['name'] ?? json['label'] ?? json['title'] ?? 'Producto destacado').toString(),
        sku: (json['sku'] ?? json['code'])?.toString(),
        description: (json['sku'] ?? json['channel'] ?? json['description'])?.toString(),
        status: (json['statusCode'] ?? json['status'] ?? 'ACTIVE').toString(),
        order: (json['priority'] as num?)?.toInt() ?? (json['order'] as num?)?.toInt(),
        views: _intAny(json, ['views', 'viewCount', 'productViews', 'impressions']),
        likes: _intAny(json, ['likes', 'likeCount', 'productLikes']),
        imageUrl: json['imageUrl']?.toString(),
      );

  DestacadoDto withMetrics(_DestacadoMetrics metrics) => DestacadoDto(
        id: id,
        title: title,
        sku: sku,
        description: description,
        status: status,
        order: order,
        views: metrics.views > 0 ? metrics.views : views,
        likes: metrics.likes > 0 ? metrics.likes : likes,
        imageUrl: imageUrl,
      );
}

int _intAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

class DestacadosNotifier extends ListNotifier<DestacadoDto> {
  final Dio _dio;
  final AuthState _auth;
  DestacadosNotifier(this._dio, this._auth) : super();

  @override
  Future<PaginatedResponse<DestacadoDto>> fetchPage(PageParams params) async {
    final scope = _scopedQuery(_auth);
    final query = params.toQueryParams()
      ..['featured'] = true
      ..addAll(scope);
    final productsFuture = _dio.get(
      '/v1/products',
      queryParameters: query,
      options: _tenantOptions(_auth, scope['tenantId']?.toString()),
    );
    final metricsFuture = _loadMetrics(scope);
    final resp = await productsFuture;
    final page = PaginatedResponse.fromJson(resp.data, DestacadoDto.fromJson);
    final metrics = await metricsFuture;
    final items = page.items.map((item) {
      final metric = metrics[item.id] ??
          (item.sku == null ? null : metrics[item.sku!]) ??
          metrics[item.title.toLowerCase()];
      return metric == null ? item : item.withMetrics(metric);
    }).toList();
    return PaginatedResponse(
      items: items,
      totalElements: page.totalElements,
      totalPages: page.totalPages,
      currentPage: page.currentPage,
      hasMore: page.hasMore,
    );
  }

  Future<Map<String, _DestacadoMetrics>> _loadMetrics(Map<String, dynamic> scope) async {
    try {
      final response = await _dio.get(
        '/v1/campaigns/reporting/products/top',
        queryParameters: {
          ...scope,
          'period': 'all',
          'limit': 200,
        },
        options: _tenantOptions(_auth, scope['tenantId']?.toString()),
      );
      final data = response.data;
      final raw = data is List
          ? data
          : data is Map
              ? ((data['content'] as List?) ?? (data['items'] as List?) ?? const [])
              : const [];
      final metrics = <String, _DestacadoMetrics>{};
      for (final item in raw.whereType<Map>()) {
        final map = Map<String, dynamic>.from(item);
        final metric = _DestacadoMetrics(
          views: _intAny(map, ['productViews', 'views', 'impressions', 'featuredViews']),
          likes: _intAny(map, ['likes', 'productLikes', 'likeCount']),
        );
        for (final key in [
          map['productId'],
          map['id'],
          map['sku'],
          map['code'],
          map['productName']?.toString().toLowerCase(),
          map['name']?.toString().toLowerCase(),
        ]) {
          final value = key?.toString().trim();
          if (value != null && value.isNotEmpty && value != 'null') {
            metrics[value] = metric;
          }
        }
      }
      return metrics;
    } catch (_) {
      return const {};
    }
  }
}

final destacadosNotifierProvider =
    StateNotifierProvider.autoDispose<DestacadosNotifier, ListState<DestacadoDto>>(
  (ref) => DestacadosNotifier(ref.watch(dioProvider), ref.watch(authNotifierProvider)),
);

class _DestacadoMetrics {
  final int views;
  final int likes;

  const _DestacadoMetrics({
    required this.views,
    required this.likes,
  });
}

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

class DestacadosScreen extends ConsumerWidget {
  const DestacadosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(destacadosNotifierProvider);
    final notifier = ref.read(destacadosNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Destacados',
      searchHint: 'Buscar destacado…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<DestacadoDto> state, DestacadosNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los destacados',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'Sin destacados',
        message: 'No hay destacados configurados.',
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
          final item = state.items[i];
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
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                splashColor: AppColors.accentLight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.ink),
                            ),
                            if (item.description != null) ...
                              [
                                const SizedBox(height: 2),
                                Text(
                                  item.description!,
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _MetricChip(icon: Icons.visibility_outlined, value: item.views),
                                _MetricChip(icon: Icons.favorite_border_rounded, value: item.likes),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (item.order != null) ...
                        [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('#${item.order}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent)),
                          ),
                          const SizedBox(width: 6),
                        ],
                      StatusBadge(status: item.status),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.star_rounded, color: AppColors.accent, size: 22),
      );
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final int value;

  const _MetricChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
