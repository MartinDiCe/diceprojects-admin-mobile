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

// ────────────────────────────── Generic Simple Master ──────────────────────────────

class SimpleMasterDto {
  final String id;
  final String name;
  final String? code;
  final String? subtitle;
  final String? status;

  const SimpleMasterDto({
    required this.id,
    required this.name,
    this.code,
    this.subtitle,
    this.status,
  });

    static SimpleMasterDto fromJson(Map<String, dynamic> json) => SimpleMasterDto(
      id: (json['id'] ??
          json['currencyId'] ??
          json['countryId'] ??
          json['stateId'] ??
          json['cityId'] ??
          json['languageId'] ??
          json['featureToggleId'] ??
          json['parameterId'])
        ?.toString() ??
        '',
      name: (json['name'] ??
          json['description'] ??
          json['currencyName'] ??
          json['countryName'] ??
          json['stateName'] ??
          json['cityName'] ??
          json['languageName'] ??
          json['parameterName'] ??
          '')
        .toString(),
      code: (json['code'] ??
          json['isoCode'] ??
          json['iso3'] ??
          json['dialCode'] ??
          json['currencyCode'])
        ?.toString(),
      subtitle:
        (json['symbol'] ?? json['nativeName'] ?? json['region'])?.toString(),
      status: (json['status'] ?? json['statusCode'])?.toString(),
      );
}

class SimpleMasterNotifier extends ListNotifier<SimpleMasterDto> {
  final Dio _dio;
  final String apiPath;
  final Map<String, dynamic>? extraParams;

  SimpleMasterNotifier(this._dio, this.apiPath, {this.extraParams}) : super();

  @override
  Future<PaginatedResponse<SimpleMasterDto>> fetchPage(PageParams params) async {
    final queryParams = params.toQueryParams();
    if (extraParams != null) queryParams.addAll(extraParams!);
    final resp = await _dio.get(apiPath, queryParameters: queryParams);
    return PaginatedResponse.fromJson(resp.data, SimpleMasterDto.fromJson);
  }
}

// ────────────────────────────── Providers ──────────────────────────────

final simpleMasterNotifierProvider = StateNotifierProvider.autoDispose
    .family<SimpleMasterNotifier, ListState<SimpleMasterDto>, String>(
  (ref, apiPath) => SimpleMasterNotifier(ref.watch(dioProvider), apiPath),
);

final simpleMasterWithParamNotifierProvider = StateNotifierProvider.autoDispose
    .family<SimpleMasterNotifier, ListState<SimpleMasterDto>,
        ({String apiPath, String? paramKey, String? paramValue})>(
  (ref, args) => SimpleMasterNotifier(
    ref.watch(dioProvider),
    args.apiPath,
    extraParams: args.paramKey != null && args.paramValue != null
        ? {args.paramKey!: args.paramValue}
        : null,
  ),
);

// ────────────────────────────── Generic Screen Widget ──────────────────────────────

class SimpleMasterScreen extends ConsumerWidget {
  final String title;
  final String apiPath;
  final String searchHint;
  final IconData icon;
  final Color iconColor;
  final Map<String, dynamic>? extraParams;

  const SimpleMasterScreen({
    super.key,
    required this.title,
    required this.apiPath,
    required this.searchHint,
    required this.icon,
    required this.iconColor,
    this.extraParams,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = extraParams != null
        ? ref.watch(simpleMasterWithParamNotifierProvider((
            apiPath: apiPath,
            paramKey: extraParams!.keys.firstOrNull,
            paramValue: extraParams!.values.firstOrNull?.toString(),
          )))
        : ref.watch(simpleMasterNotifierProvider(apiPath));

    final notifier = extraParams != null
        ? ref.read(simpleMasterWithParamNotifierProvider((
            apiPath: apiPath,
            paramKey: extraParams!.keys.firstOrNull,
            paramValue: extraParams!.values.firstOrNull?.toString(),
          )).notifier)
        : ref.read(simpleMasterNotifierProvider(apiPath).notifier);

    return AppPageScaffold(
      title: title,
      searchHint: searchHint,
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<SimpleMasterDto> state, SimpleMasterNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los registros',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return EmptyState(
        icon: icon,
        title: 'Sin $title',
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
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.ink),
                            ),
                            if (item.code != null || item.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                [item.code, item.subtitle]
                                    .where((v) => v != null)
                                    .join(' · '),
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.status != null) StatusBadge(status: item.status!),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────── Concrete Screens ──────────────────────────────

class CurrenciesScreen extends StatelessWidget {
  const CurrenciesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SimpleMasterScreen(
        title: 'Monedas',
        apiPath: '/v1/currencies',
        searchHint: 'Buscar moneda…',
        icon: Icons.attach_money_rounded,
        iconColor: Color(0xFF388E3C),
      );
}

class LanguagesScreen extends StatelessWidget {
  const LanguagesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SimpleMasterScreen(
        title: 'Idiomas',
        apiPath: '/v1/languages',
        searchHint: 'Buscar idioma…',
        icon: Icons.language_rounded,
        iconColor: Color(0xFF1565C0),
      );
}

class CountriesScreen extends StatelessWidget {
  const CountriesScreen({super.key});

  @override
  Widget build(BuildContext context) => const SimpleMasterScreen(
        title: 'Países',
        apiPath: '/v1/countries',
        searchHint: 'Buscar país…',
        icon: Icons.public_rounded,
        iconColor: Color(0xFF00695C),
      );
}

class StatesScreen extends ConsumerWidget {
  final String? countryId;
  const StatesScreen({super.key, this.countryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SimpleMasterScreen(
        title: 'Provincias / Estados',
        apiPath: '/v1/states',
        searchHint: 'Buscar provincia…',
        icon: Icons.map_rounded,
        iconColor: const Color(0xFF00695C),
        extraParams: countryId != null ? {'countryId': countryId} : null,
      );
}

class CitiesScreen extends ConsumerWidget {
  final String? stateId;
  const CitiesScreen({super.key, this.stateId});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SimpleMasterScreen(
        title: 'Ciudades',
        apiPath: '/v1/cities',
        searchHint: 'Buscar ciudad…',
        icon: Icons.location_city_rounded,
        iconColor: const Color(0xFF00695C),
        extraParams: stateId != null ? {'stateId': stateId} : null,
      );
}
