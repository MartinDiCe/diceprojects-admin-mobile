import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    if (!kReleaseMode) {
      final correlationId = options.headers['X-Correlation-Id']?.toString();
      debugPrint(
        '[HTTP →] ${options.method} ${options.uri}${correlationId != null ? ' [cid=$correlationId]' : ''}',
      );
      if (options.data != null) {
        final body = options.data.toString();
        // Mask password in logs
        final safe = body.replaceAll(RegExp(r'"password"\s*:\s*"[^"]*"'), '"password":"***"');
        debugPrint('[HTTP →] body: $safe');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!kReleaseMode) {
      final raw = response.data?.toString() ?? '';
      debugPrint('[HTTP ←] ${response.statusCode} ${response.requestOptions.uri}');
      debugPrint('[HTTP ← body] ${raw.substring(0, raw.length > 800 ? 800 : raw.length)}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!kReleaseMode) {
      debugPrint(
          '[HTTP ✗] ${err.response?.statusCode} ${err.requestOptions.uri}: ${err.message}');
      if (err.response?.data != null) {
        debugPrint('[HTTP ✗] body: ${err.response?.data}');
      }
    }
    handler.next(err);
  }
}
