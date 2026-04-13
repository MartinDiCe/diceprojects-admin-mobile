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

class LeadDto {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String status;
  final String? source;
  final String? createdAt;

  const LeadDto({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.status,
    this.source,
    this.createdAt,
  });

  factory LeadDto.fromJson(Map<String, dynamic> json) => LeadDto(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        email: json['email'],
        phone: json['phone'],
        status: json['status'] ?? 'NEW',
        source: json['source'],
        createdAt: json['createdAt'],
      );
}

class LeadsListNotifier extends ListNotifier<LeadDto> {
  final Dio _dio;
  LeadsListNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<LeadDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/leads',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, LeadDto.fromJson);
  }

  Future<void> updateStatus(String id, String newStatus) async {
    await _dio.patch('/v1/leads/$id/status', data: {'status': newStatus});
    reload();
  }
}

final leadsListNotifierProvider =
    StateNotifierProvider.autoDispose<LeadsListNotifier, ListState<LeadDto>>(
  (ref) => LeadsListNotifier(ref.watch(dioProvider)),
);

class LeadsListScreen extends ConsumerWidget {
  const LeadsListScreen({super.key});

  static const _statuses = ['NEW', 'CONTACTED', 'QUALIFIED', 'CONVERTED', 'LOST'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(leadsListNotifierProvider);
    final notifier = ref.read(leadsListNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Leads',
      searchHint: 'Buscar lead…',
      onSearch: notifier.setSearch,
      body: _buildBody(context, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext ctx,
    ListState<LeadDto> state,
    LeadsListNotifier notifier,
  ) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los leads',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.leaderboard_outlined,
        title: 'Sin leads',
        message: 'No hay leads que coincidan con la búsqueda.',
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
          final lead = state.items[i];
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
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          lead.name.isNotEmpty
                              ? lead.name[0].toUpperCase()
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
                              lead.name,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lead.email ?? lead.phone ?? '',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: lead.status),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        onSelected: (v) =>
                            notifier.updateStatus(lead.id, v),
                        itemBuilder: (_) => _statuses
                            .where((s) => s != lead.status)
                            .map((s) => PopupMenuItem(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                      ),
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
