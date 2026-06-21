import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class MobilePushRegistrationService {
  final Dio _dio;
  final FirebaseMessaging _messaging;

  MobilePushRegistrationService(
    this._dio, {
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  Future<void> registerDevice() async {
    if (kIsWeb) return;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _messaging.setAutoInitEnabled(true);

      final token = await _messaging.getToken();
      if (token == null || token.isBlank) return;

      await _sendToken(token);

      _messaging.onTokenRefresh.listen((nextToken) {
        if (nextToken.isBlank) return;
        _sendToken(nextToken);
      });
    } catch (_) {}
  }

  Future<void> _sendToken(String token) async {
    try {
      await _dio.post('/v1/notifications/push/mobile/devices', data: {
        'platform': Platform.isAndroid
            ? 'ANDROID'
            : Platform.operatingSystem.toUpperCase(),
        'deviceToken': token,
        'deviceName': 'DiceProjects Mobile',
      });
    } catch (_) {}
  }
}

extension on String {
  bool get isBlank => trim().isEmpty;
}
