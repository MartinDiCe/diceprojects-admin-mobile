import 'dart:async';

import 'package:app_diceprojects_admin/core/http/dio_client.dart';
import 'package:app_diceprojects_admin/features/notifications/data/notification_inbox_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, AsyncValue<List<NotificationInboxItem>>>(
  (ref) => NotificationInboxNotifier(ref.watch(dioProvider)),
);

final notificationUnreadCountProvider = Provider<int>((ref) {
  final state = ref.watch(notificationInboxProvider);
  return state.maybeWhen(
    data: (items) => items.where((item) => !item.read).length,
    orElse: () => 0,
  );
});

class NotificationInboxNotifier extends StateNotifier<AsyncValue<List<NotificationInboxItem>>> {
  final Dio _dio;
  Timer? _timer;

  NotificationInboxNotifier(this._dio) : super(const AsyncValue.loading()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => refresh(silent: true));
  }

  Future<void> refresh({bool silent = false}) async {
    try {
      final resp = await _dio.get('/v1/notifications/inbox', queryParameters: {
        'unreadOnly': true,
        'page': 0,
        'size': 20,
      });
      final data = resp.data;
      final raw = data is Map ? data['content'] : null;
      final items = raw is List
          ? raw.whereType<Map>().map((e) => NotificationInboxItem.fromJson(Map<String, dynamic>.from(e))).toList()
          : <NotificationInboxItem>[];
      state = AsyncValue.data(items);
    } catch (e, st) {
      if (!silent) state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(NotificationInboxItem item) async {
    state = AsyncValue.data([
      for (final current in state.valueOrNull ?? <NotificationInboxItem>[])
        if (current.notificationId != item.notificationId) current,
    ]);
    try {
      await _dio.patch('/v1/notifications/${item.notificationId}/read');
    } catch (_) {
      await refresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
