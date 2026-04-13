import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/confirm_dialog.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/create_fab.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/status_badge.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ────────────────────────────── Model ──────────────────────────────

class SellerDto {
  final String sellerId;
  final String? tenantId;
  final String sellerCode;
  final String name;
  final String? description;
  final String? email;
  final String? phone;
  final String? logoUrl;
  final String? websiteUrl;
  final bool active;

  const SellerDto({
    required this.sellerId,
    this.tenantId,
    required this.sellerCode,
    required this.name,
    this.description,
    this.email,
    this.phone,
    this.logoUrl,
    this.websiteUrl,
    required this.active,
  });

  factory SellerDto.fromJson(Map<String, dynamic> json) => SellerDto(
        sellerId: json['sellerId']?.toString() ?? json['id']?.toString() ?? '',
        tenantId: json['tenantId']?.toString(),
        sellerCode: json['sellerCode']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        email: json['email']?.toString(),
        phone: json['phone']?.toString(),
        logoUrl: json['logoUrl']?.toString(),
        websiteUrl: json['websiteUrl']?.toString(),
        active: json['active'] == true,
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class SellersListNotifier extends ListNotifier<SellerDto> {
  final Dio _dio;
  SellersListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<SellerDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/sellers',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, SellerDto.fromJson);
  }

  Future<void> toggleActive(SellerDto seller, BuildContext ctx) async {
    final action = seller.active ? 'desactivar' : 'activar';
    final confirmed = await ConfirmDialog.show(
      ctx,
      title: '${seller.active ? 'Desactivar' : 'Activar'} vendedor',
      message: '¿Estás seguro de que deseas $action a ${seller.name}?',
      isDangerous: seller.active,
    );
    if (!confirmed) return;
    final endpoint =
        seller.active ? '/v1/sellers/${seller.sellerId}/deactivate' : '/v1/sellers/${seller.sellerId}/activate';
    await _dio.patch(endpoint);
    reload();
  }
}

final sellersListNotifierProvider =
    StateNotifierProvider.autoDispose<SellersListNotifier, ListState<SellerDto>>(
  (ref) => SellersListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class SellersListScreen extends ConsumerWidget {
  const SellersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellersListNotifierProvider);
    final notifier = ref.read(sellersListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Vendedores',
      searchHint: 'Buscar vendedor…',
      onSearch: notifier.setSearch,
      floatingActionButton: CreateFab(
        onPressed: () => context.push('/organization/sellers/new'),
        label: 'Nuevo vendedor',
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<SellerDto> state,
    SellersListNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los vendedores',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.store_mall_directory_rounded,
        title: 'Sin vendedores',
        message: 'No hay vendedores que coincidan.',
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollEndNotification &&
            n.metrics.extentAfter < 200 &&
            state.hasMore &&
            !state.isLoadingMore) {
          notifier.loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, i) {
          if (i == state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final seller = state.items[i];
          return _SellerCard(seller: seller, notifier: notifier);
        },
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  final SellerDto seller;
  final SellersListNotifier notifier;

  const _SellerCard({required this.seller, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surface : Colors.white;
    final textMuted = isDark ? AppColors.sidebarTextMuted : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.white.withValues(alpha: 0.08)
              : AppColors.border.withValues(alpha: 0.50),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              isDark ? AppColors.accentDark : AppColors.accentLight,
          child: Text(
            seller.name.isNotEmpty ? seller.name[0].toUpperCase() : 'V',
            style: TextStyle(
              color: isDark ? AppColors.white : AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          seller.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              seller.sellerCode,
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            if (seller.email != null) ...[
              const SizedBox(height: 2),
              Text(
                seller.email!,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
            ],
            const SizedBox(height: 4),
            StatusBadge(status: seller.active ? 'ACTIVE' : 'INACTIVE'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: textMuted, size: 20),
          onSelected: (v) {
            if (v == 'edit') {
              context.push('/organization/sellers/${seller.sellerId}/edit');
            } else if (v == 'toggle') {
              notifier.toggleActive(seller, context);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(seller.active ? 'Desactivar' : 'Activar'),
            ),
          ],
        ),
      ),
    );
  }
}
