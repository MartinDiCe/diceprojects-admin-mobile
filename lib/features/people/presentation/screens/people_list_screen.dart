import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/utils/list_state.dart';
import 'package:app_diceprojects_admin/core/utils/pagination.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
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

class PersonDto {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final String? documentNumber;
  final String status;

  const PersonDto({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.documentNumber,
    required this.status,
  });

  factory PersonDto.fromJson(Map<String, dynamic> json) => PersonDto(
        id: json['id']?.toString() ?? '',
        fullName: '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
        email: json['email'],
        phone: json['phone'],
        documentNumber: json['documentNumber'],
        status: json['status'] ?? 'ACTIVE',
      );
}

// ────────────────────────────── Notifier ──────────────────────────────

class PeopleListNotifier extends ListNotifier<PersonDto> {
  final Dio _dio;
  PeopleListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<PersonDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/people',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, PersonDto.fromJson);
  }
}

final peopleListNotifierProvider =
    StateNotifierProvider.autoDispose<PeopleListNotifier, ListState<PersonDto>>(
  (ref) => PeopleListNotifier(ref.watch(dioProvider)),
);

// ────────────────────────────── Screen ──────────────────────────────

class PeopleListScreen extends ConsumerWidget {
  const PeopleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(peopleListNotifierProvider);
    final notifier = ref.read(peopleListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Personal',
      searchHint: 'Buscar persona…',
      onSearch: notifier.setSearch,
      floatingActionButton: CreateFab(
        onPressed: () => context.push('/people/new'),
        label: 'Nueva persona',
      ),
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(BuildContext ctx, ListState<PersonDto> state,
      PeopleListNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar el personal',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.badge_outlined,
        title: 'Sin personas',
        message: 'No hay personas que coincidan con la búsqueda.',
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
          final person = state.items[i];
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
                onTap: () => ctx.push('/people/${person.id}/edit'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          person.fullName.isNotEmpty
                              ? person.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.fullName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              person.email ??
                                  person.phone ??
                                  person.documentNumber ??
                                  '',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: person.status),
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
}
