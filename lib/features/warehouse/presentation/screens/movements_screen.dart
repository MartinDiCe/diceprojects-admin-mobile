import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/core/ui/app_colors.dart';
import 'package:app_diceprojects_admin/core/ui/layout/app_page_scaffold.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/empty_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/error_state.dart';
import 'package:app_diceprojects_admin/core/ui/widgets/loading_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/${dt.year} $h:$mi';
  } catch (_) {
    return raw.split('T').first;
  }
}

// ────────────────────────────── Model ──────────────────────────────

class MovementDto {
  final String? movementId;
  final String? warehouseId;
  final String? sku;
  final num quantity;
  final String? movementTypeCode;
  final String? note;
  final String? createdAt;

  const MovementDto({
    this.movementId,
    this.warehouseId,
    this.sku,
    required this.quantity,
    this.movementTypeCode,
    this.note,
    this.createdAt,
  });

  factory MovementDto.fromJson(Map<String, dynamic> json) => MovementDto(
        movementId: json['movementId']?.toString(),
        warehouseId: json['warehouseId']?.toString(),
        sku: json['sku']?.toString(),
        quantity: (json['quantity'] as num?) ?? 0,
        movementTypeCode: json['movementTypeCode']?.toString(),
        note: json['note']?.toString(),
        createdAt: json['createdAt']?.toString(),
      );
}

// ────────────────────────────── State & Notifier ──────────────────────────────

class _MovementsState {
  final bool isLoading;
  final List<MovementDto> items;
  final String? error;
  final bool hasMore;
  final int page;

  const _MovementsState({
    this.isLoading = true,
    this.items = const [],
    this.error,
    this.hasMore = false,
    this.page = 0,
  });

  _MovementsState copyWith({
    bool? isLoading,
    List<MovementDto>? items,
    String? error,
    bool? hasMore,
    int? page,
    bool clearError = false,
  }) =>
      _MovementsState(
        isLoading: isLoading ?? this.isLoading,
        items: items ?? this.items,
        error: clearError ? null : (error ?? this.error),
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
      );
}

class _MovementsNotifier extends StateNotifier<_MovementsState> {
  final Dio _dio;
  final String warehouseId;

  _MovementsNotifier(this._dio, this.warehouseId)
      : super(const _MovementsState()) {
    _load(0);
  }

  Future<void> _load(int page, {bool append = false}) async {
    state = state.copyWith(isLoading: !append, clearError: true);
    try {
      final resp = await _dio.get('/v1/stock/movements', queryParameters: {
        'warehouseId': warehouseId,
        'page': page,
        'size': 20,
      });
      final raw = resp.data;
      List<dynamic> list;
      bool hasMore = false;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        final m = raw is Map<String, dynamic> ? raw : Map<String, dynamic>.from(raw);
        list = (m['content'] as List?) ?? [];
        final last = m['last'] as bool? ?? true;
        hasMore = !last;
      } else {
        list = [];
      }
      final items = list
          .map((e) => MovementDto.fromJson(
              e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(
        isLoading: false,
        items: append ? [...state.items, ...items] : items,
        hasMore: hasMore,
        page: page,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void reload() => _load(0);
  void loadMore() {
    if (state.hasMore && !state.isLoading) _load(state.page + 1, append: true);
  }
}

final movementsNotifierProvider = StateNotifierProvider.autoDispose
    .family<_MovementsNotifier, _MovementsState, String>(
  (ref, warehouseId) => _MovementsNotifier(ref.watch(dioProvider), warehouseId),
);

// ────────────────────────────── Screen ──────────────────────────────

class MovementsScreen extends ConsumerWidget {
  final String warehouseId;
  const MovementsScreen({super.key, required this.warehouseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movementsNotifierProvider(warehouseId));
    final notifier = ref.read(movementsNotifierProvider(warehouseId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.sidebarTextMuted : AppColors.textSecondary;

    return AppPageScaffold(
      title: 'Movimientos',
      body: state.isLoading
          ? const LoadingState()
          : state.error != null && state.items.isEmpty
              ? ErrorState(
                  title: 'Error al cargar movimientos',
                  message: state.error!,
                  onRetry: notifier.reload,
                )
              : state.items.isEmpty
                  ? const EmptyState(
                      icon: Icons.swap_horiz_rounded,
                      title: 'Sin movimientos',
                      message: 'Este depósito no tiene movimientos registrados.',
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollEndNotification &&
                            n.metrics.extentAfter < 200 &&
                            state.hasMore) {
                          notifier.loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: state.items.length,
                        itemBuilder: (ctx, i) {
                          final m = state.items[i];
                          final isIn = (m.quantity) >= 0;
                          final cardBg = isDark ? AppColors.surface : Colors.white;
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
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isIn
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.red.withValues(alpha: 0.15),
                                child: Icon(
                                  isIn
                                      ? Icons.arrow_downward_rounded
                                      : Icons.arrow_upward_rounded,
                                  color: isIn ? Colors.green.shade700 : Colors.red.shade700,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                m.movementTypeCode ?? 'Movimiento',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (m.sku != null)
                                    Text('SKU: ${m.sku}',
                                        style: TextStyle(
                                            fontSize: 12, color: textMuted)),
                                  if (m.note != null)
                                    Text(m.note!,
                                        style: TextStyle(
                                            fontSize: 12, color: textMuted)),
                                  if (m.createdAt != null)
                                    Text(_fmtDate(m.createdAt),
                                        style: TextStyle(
                                            fontSize: 11, color: textMuted)),
                                ],
                              ),
                              trailing: Text(
                                '${isIn ? '+' : ''}${m.quantity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: isIn
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
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
