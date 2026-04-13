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

class WarehouseTypeDto {
  final String code;
  final String name;
  final String? description;
  final bool active;

  const WarehouseTypeDto({
    required this.code,
    required this.name,
    this.description,
    required this.active,
  });

  factory WarehouseTypeDto.fromJson(Map<String, dynamic> json) => WarehouseTypeDto(
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class WarehouseTypesNotifier extends ListNotifier<WarehouseTypeDto> {
  final Dio _dio;
  WarehouseTypesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<WarehouseTypeDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/warehouse-types',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, WarehouseTypeDto.fromJson);
  }
}

final warehouseTypesNotifierProvider =
    StateNotifierProvider.autoDispose<WarehouseTypesNotifier, ListState<WarehouseTypeDto>>(
  (ref) => WarehouseTypesNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class WarehouseTypesScreen extends ConsumerWidget {
  const WarehouseTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(warehouseTypesNotifierProvider);
    final notifier = ref.read(warehouseTypesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Tipos de depósito',
      searchHint: 'Buscar tipo…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<WarehouseTypeDto> state,
    WarehouseTypesNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los tipos',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.category_rounded,
        title: 'Sin tipos',
        message: 'No hay tipos de depósito registrados.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: state.items.length,
      itemBuilder: (ctx, i) {
        final t = state.items[i];
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
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
              child: Text(
                t.code.isNotEmpty ? t.code[0] : 'T',
                style: TextStyle(
                  color: isDark ? AppColors.white : AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(t.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.code, style: TextStyle(fontSize: 12, color: textMuted)),
                if (t.description != null)
                  Text(t.description!,
                      style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 4),
                  StatusBadge(status: t.active ? 'ACTIVE' : 'INACTIVE'),
              ],
            ),
          ),
        );
      },
    );
  }
}
