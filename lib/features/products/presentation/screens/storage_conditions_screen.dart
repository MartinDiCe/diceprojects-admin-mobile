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

class StorageConditionDto {
  final String id;
  final String code;
  final String name;
  final String? description;
  final bool active;
  final bool isGlobal;

  const StorageConditionDto({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.active,
    required this.isGlobal,
  });

  factory StorageConditionDto.fromJson(Map<String, dynamic> json) =>
      StorageConditionDto(
        id: json['conditionId']?.toString() ?? json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        active: json['active'] == true,
        isGlobal: json['companyId'] == null || json['isGlobal'] == true,
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class StorageConditionsNotifier extends ListNotifier<StorageConditionDto> {
  final Dio _dio;
  StorageConditionsNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<StorageConditionDto>> fetchPage(
      PageParams params) async {
    final resp = await _dio.get(
      '/v1/storage-conditions',
      queryParameters: {...params.toQueryParams(), 'size': 50},
    );
    return PaginatedResponse.fromJson(resp.data, StorageConditionDto.fromJson);
  }
}

final storageConditionsNotifierProvider = StateNotifierProvider.autoDispose<
    StorageConditionsNotifier, ListState<StorageConditionDto>>(
  (ref) => StorageConditionsNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class StorageConditionsScreen extends ConsumerWidget {
  const StorageConditionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(storageConditionsNotifierProvider);
    final notifier = ref.read(storageConditionsNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Condiciones de almacenamiento',
      searchHint: 'Buscar condición…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(BuildContext ctx, ListState<StorageConditionDto> state,
      StorageConditionsNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
          title: 'Error al cargar condiciones',
          message: state.error!,
          onRetry: notifier.reload);
    }
    if (state.items.isEmpty) {
      return const EmptyState(
          icon: Icons.thermostat_rounded,
          title: 'Sin condiciones',
          message: 'No hay condiciones de almacenamiento registradas.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: state.items.length,
      itemBuilder: (ctx, i) => _ConditionCard(item: state.items[i]),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  final StorageConditionDto item;
  const _ConditionCard({required this.item});

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
          child: Icon(Icons.thermostat_rounded,
              color: isDark ? AppColors.white : AppColors.accent, size: 18),
        ),
        title: Row(children: [
          Flexible(
            child: Text(item.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
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
