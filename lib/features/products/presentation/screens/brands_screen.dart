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

// ────────────────────────────── Model ──────────────────────────────

class BrandDto {
  final String id;
  final String code;
  final String name;
  final String? description;
  final bool active;
  final bool isGlobal;

  const BrandDto({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.active,
    required this.isGlobal,
  });

  factory BrandDto.fromJson(Map<String, dynamic> json) => BrandDto(
        id: json['brandId']?.toString() ?? json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
        isGlobal: json['companyId'] == null || json['isGlobal'] == true,
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class BrandsNotifier extends ListNotifier<BrandDto> {
  final Dio _dio;
  BrandsNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<BrandDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/brands',
      queryParameters: {...params.toQueryParams(), 'size': 50},
    );
    return PaginatedResponse.fromJson(resp.data, BrandDto.fromJson);
  }
}

final brandsNotifierProvider =
    StateNotifierProvider.autoDispose<BrandsNotifier, ListState<BrandDto>>(
  (ref) => BrandsNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class BrandsScreen extends ConsumerWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(brandsNotifierProvider);
    final notifier = ref.read(brandsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Marcas',
      searchHint: 'Buscar marca…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
      BuildContext ctx, ListState<BrandDto> state, BrandsNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
          title: 'Error al cargar marcas',
          message: state.error!,
          onRetry: notifier.reload);
    }
    if (state.items.isEmpty) {
      return const EmptyState(
          icon: Icons.branding_watermark_rounded,
          title: 'Sin marcas',
          message: 'No hay marcas registradas.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: state.items.length,
      itemBuilder: (ctx, i) => _BrandCard(item: state.items[i]),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final BrandDto item;
  const _BrandCard({required this.item});

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
          backgroundColor: isDark ? AppColors.accentDark : AppColors.accentLight,
          child: Icon(Icons.branding_watermark_rounded,
              color: isDark ? AppColors.white : AppColors.accent, size: 18),
        ),
        title: Row(children: [
          Text(item.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          if (item.isGlobal) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Global',
                  style: TextStyle(
                      fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600)),
            ),
          ]
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.code, style: TextStyle(fontSize: 12, color: textMuted)),
          if (item.description != null)
            Text(item.description!, style: TextStyle(fontSize: 12, color: textMuted)),
          const SizedBox(height: 4),
          StatusBadge(status: item.active ? 'ACTIVE' : 'INACTIVE'),
        ]),
      ),
    );
  }
}
