import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'app_error.dart';

class ErrorHandler {
  static AppError handle(Object error) {
    if (error is AppError) return error;
    if (error is DioException) return _handleDio(error);
    if (error is SocketException) return AppError.network();
    // Dart-level parse/cast errors — show real message to help diagnose
    if (error is FormatException) {
      return AppError(
        message: kReleaseMode
            ? 'Error al procesar la respuesta del servidor.'
            : 'FormatException: ${error.message}',
        code: 'PARSE_ERROR',
      );
    }
    if (error is TypeError) {
      return AppError(
        message: kReleaseMode
            ? 'Error al procesar la respuesta del servidor.'
            : 'TypeError: $error',
        code: 'TYPE_ERROR',
      );
    }
    return AppError(
      message: kReleaseMode
          ? 'Error inesperado. Por favor, intentá de nuevo.'
          : 'ERROR [${error.runtimeType}]: $error',
      code: 'UNKNOWN_${error.runtimeType}',
    );
  }

  static AppError _handleDio(DioException e) {
    // Si el ErrorInterceptor ya procesó el error, lo devolvemos directamente
    if (e.error is AppError) return e.error as AppError;

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const AppError(
          message: 'Tiempo de conexión agotado. Verificá tu red.',
          code: 'TIMEOUT',
        );
      case DioExceptionType.connectionError:
        return AppError.network();
      case DioExceptionType.badCertificate:
        return const AppError(
          message: 'Error de certificado SSL. Verificá tu conexión.',
          code: 'SSL_ERROR',
        );
      case DioExceptionType.badResponse:
        return _handleBadResponse(e.response);
      default:
        final msg = e.message?.isNotEmpty == true
            ? e.message!
            : e.error?.toString() ?? 'Error de red desconocido.';
        return AppError(message: msg, code: 'UNKNOWN');
    }
  }

  static AppError _handleBadResponse(Response? response) {
    if (response == null) return AppError.unknown();
    final data = response.data;
    final statusCode = response.statusCode ?? 500;

    if (statusCode == 401) return AppError.unauthorized();
    if (statusCode == 403) return AppError.forbidden();

    if (data is Map<String, dynamic>) {
      return AppError.fromJson({...data, 'status': statusCode});
    }
    // In non-release mode, show real body for diagnosis
    if (!kReleaseMode) {
      final body = data?.toString();
      final snippet = (body == null || body.isEmpty)
          ? 'sin body'
          : body.substring(0, body.length > 200 ? 200 : body.length);
      return AppError(
        message: 'HTTP $statusCode: $snippet',
        statusCode: statusCode,
      );
    }
    return AppError(
      message: 'Error del servidor ($statusCode)',
      statusCode: statusCode,
    );
  }
}
