import 'dart:async';
import 'dart:convert';

import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final FutureOr<void> Function()? onTokenExpired;

  AuthInterceptor(this._storage, {this.onTokenExpired});

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
      if (_isExpired(token)) {
        await _storage.delete(AppConfig.tokenKey);
        await onTokenExpired?.call();
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 401,
              data: const {'message': 'Sesión expirada'},
            ),
            type: DioExceptionType.badResponse,
            message: 'Sesión expirada',
          ),
        );
        return;
      }
      options.headers['Authorization'] = 'Bearer $token';

      // Inject tenantId for multi-tenant scope (mirrors web buildParams logic)
      final claims = _decodeJwt(token);
      final tenantId = claims['tenantId']?.toString();
      final sellerId = claims['sellerId']?.toString();
      final sellerIds = claims['sellerIds'];
      final isAdminGlobal = tenantId == null || tenantId.trim().isEmpty;
      if (!isAdminGlobal && tenantId.trim().isNotEmpty) {
        options.queryParameters['tenantId'] = tenantId;
        options.headers['X-Tenant-Id'] = tenantId;
      }
      if (sellerId != null && sellerId.trim().isNotEmpty) {
        options.queryParameters.putIfAbsent('sellerId', () => sellerId.trim());
        options.headers['X-Seller-Id'] = sellerId.trim();
      } else if (sellerIds is List && sellerIds.isNotEmpty) {
        final csv = sellerIds
            .map((id) => id.toString().trim())
            .where((id) => id.isNotEmpty)
            .join(',');
        if (csv.isNotEmpty) {
          options.queryParameters.putIfAbsent('sellerIds', () => csv);
          options.headers['X-Seller-Ids'] = csv;
        }
      }
    }
    handler.next(options);
  }
}

bool _isExpired(String token) {
  final claims = _decodeJwt(token);
  final exp = claims['exp'];
  final expSeconds =
      exp is num ? exp.toInt() : int.tryParse(exp?.toString() ?? '');
  if (expSeconds == null) return true;
  final expiresAt = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
  return !expiresAt.isAfter(DateTime.now());
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
