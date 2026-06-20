import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/app_entity_tile.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogMasterConfig {
  final String title;
  final String endpoint;
  final IconData icon;
  final String emptyTitle;

  const CatalogMasterConfig({
    required this.title,
    required this.endpoint,
    required this.icon,
    required this.emptyTitle,
  });
}

class CatalogMasterDto {
  final String code;
  final String name;
  final String? description;
  final bool active;

  const CatalogMasterDto({
    required this.code,
    required this.name,
    this.description,
    required this.active,
  });

  factory CatalogMasterDto.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ??
            json['label'] ??
            json['description'] ??
            json['code'] ??
            '')
        .toString()
        .trim();
    return CatalogMasterDto(
      code: json['code']?.toString().trim() ?? '',
      name: rawName.isEmpty ? 'Sin nombre' : rawName,
      description: json['description']?.toString().trim(),
      active: json['active'] != false,
    );
  }

  String get statusCode => active ? 'ACTIVE' : 'INACTIVE';
}

class CatalogMasterNotifier extends ListNotifier<CatalogMasterDto> {
  final Dio _dio;
  final CatalogMasterConfig config;

  CatalogMasterNotifier(this._dio, this.config) : super();

  @override
  Future<PaginatedResponse<CatalogMasterDto>> fetchPage(
      PageParams params) async {
    final query = params.toQueryParams()
      ..['size'] = 50
      ..['pageSize'] = 50;
    final response = await _dio.get(config.endpoint, queryParameters: query);
    return PaginatedResponse.fromJson(response.data, CatalogMasterDto.fromJson);
  }
}

final catalogMasterProvider = StateNotifierProvider.autoDispose.family<
    CatalogMasterNotifier, ListState<CatalogMasterDto>, CatalogMasterConfig>(
  (ref, config) => CatalogMasterNotifier(ref.watch(dioProvider), config),
);

class CatalogMasterScreen extends ConsumerWidget {
  final CatalogMasterConfig config;

  const CatalogMasterScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogMasterProvider(config));
    final notifier = ref.read(catalogMasterProvider(config).notifier);

    return AppPageScaffold(
      title: config.title,
      searchHint: 'Buscar...',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
    ListState<CatalogMasterDto> state,
    CatalogMasterNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar ${config.title.toLowerCase()}',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: config.icon,
        title: config.emptyTitle,
        message: 'No hay registros que coincidan con la búsqueda.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => notifier.reload(),
      child: NotificationListener<ScrollNotification>(
        onNotification: notifier.onScrollNotification,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == state.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: LoadingState(),
              );
            }
            return _CatalogMasterTile(
              item: state.items[index],
              icon: config.icon,
            );
          },
        ),
      ),
    );
  }
}

class _CatalogMasterTile extends StatelessWidget {
  final CatalogMasterDto item;
  final IconData icon;

  const _CatalogMasterTile({required this.item, required this.icon});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.code.isNotEmpty) item.code,
      if ((item.description ?? '').isNotEmpty) item.description!,
    ].join(' · ');

    return AppEntityTile(
      icon: icon,
      title: item.name,
      details: [subtitle],
      status: item.statusCode,
    );
  }
}
