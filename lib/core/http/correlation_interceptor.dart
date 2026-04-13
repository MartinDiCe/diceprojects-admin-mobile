import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

class CorrelationInterceptor extends Interceptor {
  static const _uuid = Uuid();

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Correlation-Id'] = _uuid.v4();
    handler.next(options);
  }
}
