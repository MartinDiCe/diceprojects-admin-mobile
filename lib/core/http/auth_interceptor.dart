import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/storage/secure_storage.dart';
import 'package:app_diceprojects_admin/core/utils/jwt_decoder.dart';
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
      // Avoid sending expired tokens — can cause the gateway/security filters
      // to reject even public endpoints, and breaks re-login.
      if (JwtDecoder.isExpired(token)) {
        await _storage.delete(AppConfig.tokenKey);
        handler.next(options);
        return;
      }

      options.headers['Authorization'] = 'Bearer $token';

      // Inject tenantId for multi-tenant scope (mirrors web buildParams logic)
      final claims = JwtDecoder.decode(token);
      final tenantId = claims['tenantId']?.toString();
      final isAdminGlobal = tenantId == null || tenantId.trim().isEmpty;
      if (!isAdminGlobal && tenantId.trim().isNotEmpty) {
        options.queryParameters['tenantId'] = tenantId;
      }
    }
    handler.next(options);
  }
}
