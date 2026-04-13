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

class SenderProfileDto {
  final String id;
  final String name;
  final String? channel;
  final String? fromAddress;
  final bool isDefault;
  final String status;

  const SenderProfileDto({
    required this.id,
    required this.name,
    this.channel,
    this.fromAddress,
    required this.isDefault,
    required this.status,
  });

  factory SenderProfileDto.fromJson(Map<String, dynamic> json) =>
      SenderProfileDto(
        id: (json['id'])?.toString() ?? '',
        // Backend key: senderProfileName
        name: (json['senderProfileName'] ?? json['name'] ?? '').toString(),
        // Backend key: provider (smtp, ses, etc.)
        channel: (json['provider'] ?? json['channel'])?.toString(),
        // Backend key: senderIdentifier (email address / phone / etc.)
        fromAddress: (json['senderIdentifier'] ?? json['fromAddress'])?.toString(),
        // Backend serializes boolean isDefault; Jackson may use 'default' key
        isDefault: json['isDefault'] == true || json['default'] == true,
        // Backend key: active (boolean) → convert to status string
        status: json['active'] == true
            ? 'ACTIVE'
            : (json['active'] == false ? 'INACTIVE' : (json['status'] ?? 'ACTIVE').toString()),
      );
}

class SenderProfilesNotifier extends ListNotifier<SenderProfileDto> {
  final Dio _dio;
  SenderProfilesNotifier(this._dio) : super();

  @override
  Future<PaginatedResponse<SenderProfileDto>> fetchPage(PageParams params) async {
    final resp = await _dio.get(
      '/v1/notification-sender-profiles',
      queryParameters: params.toQueryParams(),
    );
    return PaginatedResponse.fromJson(resp.data, SenderProfileDto.fromJson);
  }
}

final senderProfilesNotifierProvider =
    StateNotifierProvider.autoDispose<SenderProfilesNotifier, ListState<SenderProfileDto>>(
  (ref) => SenderProfilesNotifier(ref.watch(dioProvider)),
);

class SenderProfilesScreen extends ConsumerWidget {
  const SenderProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(senderProfilesNotifierProvider);
    final notifier = ref.read(senderProfilesNotifierProvider.notifier);

    return AppPageScaffold(
      title: 'Perfiles de Envío',
      searchHint: 'Buscar perfil…',
      onSearch: notifier.setSearch,
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(
      ListState<SenderProfileDto> state, SenderProfilesNotifier notifier) {
    if (state.isLoading) return const LoadingState();
    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        title: 'No pudimos cargar los perfiles',
        message: state.error!,
        onRetry: notifier.reload,
      );
    }
    if (state.items.isEmpty) {
      return const EmptyState(
        icon: Icons.send_outlined,
        title: 'Sin perfiles',
        message: 'No hay perfiles de envío configurados.',
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
          final p = state.items[i];
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                p.name,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.ink),
                              ),
                              if (p.isDefault) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Default',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.accent,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (p.channel != null) p.channel!,
                              if (p.fromAddress != null) p.fromAddress!,
                            ].join(' · '),
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge(status: p.status),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
