import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CouponDto {
  final String id;
  final String code;
  final String status;
  final String? description;
  final String? sellerName;
  final String? discount;

  const CouponDto({
    required this.id,
    required this.code,
    required this.status,
    this.description,
    this.sellerName,
    this.discount,
  });

  factory CouponDto.fromJson(Map<String, dynamic> json) {
    final type = (json['discountType'] ?? json['type'])?.toString();
    final value = json['discountValue'] ?? json['value'];
    return CouponDto(
      id: (json['couponId'] ?? json['id'])?.toString() ?? '',
      code: (json['code'] ?? json['name'] ?? 'Cupón').toString(),
      status: (json['status'] ?? json['statusCode'] ?? 'ACTIVE').toString(),
      description: (json['description'] ?? json['name'])?.toString(),
      sellerName:
          (json['sellerName'] ?? json['sellerBusinessName'])?.toString(),
      discount: value == null
          ? type
          : [value.toString(), if (type != null) type].join(' '),
    );
  }
}

class CouponsNotifier extends ListNotifier<CouponDto> {
  final Dio _dio;

  CouponsNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<CouponDto>> fetchPage(PageParams params) async {
    final response = await _dio.get(
      '/v1/coupons',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(response.data, CouponDto.fromJson);
  }
}

final couponsNotifierProvider =
    StateNotifierProvider.autoDispose<CouponsNotifier, ListState<CouponDto>>(
  (ref) => CouponsNotifier(ref.watch(dioProvider)),
);

class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(couponsNotifierProvider);
    final notifier = ref.read(couponsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Cupones',
      searchHint: 'Buscar cupón...',
      onSearch: notifier.setSearch,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: notifier.reload,
        ),
      ],
      body: _CouponsBody(state: state, notifier: notifier),
    );
  }
}

class _CouponsBody extends StatelessWidget {
  final ListState<CouponDto> state;
  final CouponsNotifier notifier;

  const _CouponsBody({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar cupones',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.confirmation_number_rounded,
        title: 'Sin cupones',
        message: 'No hay cupones para los filtros seleccionados.',
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
            final coupon = state.items[index];
            return _CouponCard(coupon: coupon);
          },
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponDto coupon;

  const _CouponCard({required this.coupon});

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
            child: const Icon(Icons.confirmation_number_rounded,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.code,
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
                    if (coupon.discount != null) coupon.discount!,
                    if (coupon.sellerName != null) coupon.sellerName!,
                    if (coupon.description != null) coupon.description!,
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
          StatusBadge(status: coupon.status),
        ],
      ),
    );
  }
}
