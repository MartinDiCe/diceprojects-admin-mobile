import 'dart:convert';

import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  AuthInterceptor(this._storage);

  bool _isPublicAuthPath(String path) {
    // NOTE: baseUrl already includes `/api`, so Dio paths here are usually like `/auth/login`.
    // Keep checks tolerant in case a different baseUrl is used.
    return path == '/auth/login' ||
        path.endsWith('/auth/login') ||
        path == '/auth/invite/accept' ||
        path.endsWith('/auth/invite/accept') ||
        path.contains('/auth/oauth2/');
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublicAuthPath(options.path)) {
      handler.next(options);
      return;
    }

    final token = await _storage.read(AppConfig.tokenKey);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';

      // Inject tenantId for multi-tenant scope (mirrors web buildParams logic)
      final claims = _decodeJwt(token);
      final tenantId = claims['tenantId']?.toString();
      final isAdminGlobal = tenantId == null || tenantId.trim().isEmpty;
      if (!isAdminGlobal && tenantId.trim().isNotEmpty) {
        options.queryParameters['tenantId'] = tenantId;
      }
    }
    handler.next(options);
  }
}

Map<String, dynamic> _decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length < 2) return const {};
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = jsonDecode(decoded);
    return json is Map ? Map<String, dynamic>.from(json) : const {};
  } catch (_) {
    return const {};
  }
}
