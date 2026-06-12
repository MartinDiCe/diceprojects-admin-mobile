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

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, AsyncValue<List<NotificationPreferenceItem>>>(
  (ref) => NotificationPreferencesNotifier(ref.watch(dioProvider)),
);

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

class NotificationPreferencesNotifier extends StateNotifier<AsyncValue<List<NotificationPreferenceItem>>> {
  final Dio _dio;

  NotificationPreferencesNotifier(this._dio) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final resp = await _dio.get('/v1/notifications/preferences');
      final data = resp.data;
      final items = data is List
          ? data.whereType<Map>().map((e) => NotificationPreferenceItem.fromJson(Map<String, dynamic>.from(e))).toList()
          : <NotificationPreferenceItem>[];
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggle(NotificationPreferenceItem item, String channel) async {
    final previous = state.valueOrNull ?? <NotificationPreferenceItem>[];
    final next = switch (channel) {
      'bell' => item.copyWith(bellEnabled: !item.bellEnabled),
      'web' => item.copyWith(webPushEnabled: !item.webPushEnabled),
      'mobile' => item.copyWith(mobilePushEnabled: !item.mobilePushEnabled),
      'email' => item.copyWith(emailEnabled: !item.emailEnabled),
      _ => item,
    };
    state = AsyncValue.data([
      for (final current in previous)
        if (current.typeCode == item.typeCode) next else current,
    ]);
    try {
      final resp = await _dio.put('/v1/notifications/preferences/${Uri.encodeComponent(item.typeCode)}', data: next.toJson());
      final saved = NotificationPreferenceItem.fromJson(Map<String, dynamic>.from(resp.data as Map));
      state = AsyncValue.data([
        for (final current in state.valueOrNull ?? <NotificationPreferenceItem>[])
          if (current.typeCode == item.typeCode) saved else current,
      ]);
    } catch (e, st) {
      state = AsyncValue.data(previous);
      Error.throwWithStackTrace(e, st);
    }
  }
}
