import 'package:app_diceprojects_admin/core/config/app_config.dart';
import 'package:app_diceprojects_admin/core/http/auth_interceptor.dart';
import 'package:app_diceprojects_admin/core/http/correlation_interceptor.dart';
import 'package:app_diceprojects_admin/core/http/error_interceptor.dart';
import 'package:app_diceprojects_admin/core/http/logging_interceptor.dart';
import 'package:app_diceprojects_admin/core/storage/secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (_) => SecureStorageService(),
);

/// Provider separado para el interceptor de auth, permite que [AuthNotifier]
/// registre su callback de logout sin crear una dependencia circular.
final authInterceptorProvider = Provider<AuthInterceptor>((ref) {
  final storage = ref.read(secureStorageProvider);
  return AuthInterceptor(storage);
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final authInterceptor = ref.read(authInterceptorProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    CorrelationInterceptor(),
    authInterceptor,
    LoggingInterceptor(),
    ErrorInterceptor(), // último: convierte errores HTTP en AppError estructurado
  ]);

  return dio;
});
