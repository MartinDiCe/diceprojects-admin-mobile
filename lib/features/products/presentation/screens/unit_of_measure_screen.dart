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

class _CatalogDto {
  final String code;
  final String name;
  final String? description;
  final bool active;
  const _CatalogDto({required this.code, required this.name, this.description, required this.active});
  factory _CatalogDto.fromJson(Map<String, dynamic> json) => _CatalogDto(
    code: json['code']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    description: json['description']?.toString(),
    active: json['active'] == true,
  );
}

class _Notifier extends ListNotifier<_CatalogDto> {
  final Dio _dio;
  _Notifier(this._dio) : super();
  @override
  Future<PaginatedResponse<_CatalogDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get('/v1/unit-of-measure', queryParameters: params.toQueryParams());
    return PaginatedResponse.fromJson(resp.data, _CatalogDto.fromJson);
  }
}

final _unitofmeasurescreenProvider = StateNotifierProvider.autoDispose<_Notifier, ListState<_CatalogDto>>(
  (ref) => _Notifier(ref.watch(dioProvider)),
);

class UnitOfMeasureScreen extends ConsumerWidget {
  const UnitOfMeasureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_unitofmeasurescreenProvider);
    final notifier = ref.read(_unitofmeasurescreenProvider.notifier);
    return AppPageScaffold(
      title: 'Unidades de Medida',
      searchHint: 'Buscar…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(ListState<_CatalogDto> state, _Notifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) return ErrorState(title: 'Error al cargar', message: state.error!, onRetry: notifier.reload);
    if (state.items.isEmpty) return EmptyState(icon: Icons.straighten_rounded, title: 'Sin registros', message: 'No hay datos en este catálogo.');
    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (ctx, i) {
          if (i == state.items.length) return const Padding(padding: EdgeInsets.all(16), child: LoadingState());
          final item = state.items[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))]),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(6)), child: Text(item.code, style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600))),
                ]),
                if (item.description != null && item.description!.isNotEmpty) ...[const SizedBox(height: 4), Text(item.description!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary))],
              ])),
              const SizedBox(width: 8),
              StatusBadge(status: item.active ? 'ACTIVO' : 'INACTIVO'),
            ]),
          );
        },
      ),
    );
  }
}
