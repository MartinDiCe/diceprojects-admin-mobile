import 'package:app_diceprojects_admin/core/errors/app_error.dart';
import 'package:dio/dio.dart';

/// Interceptor que transforma todos los [DioException] de tipo [badResponse]
/// en [AppError] bien estructurados, extrayendo el cuerpo de error del backend.
///
/// Debe ser el ÚLTIMO interceptor en la cadena para que los otros (auth, logging)
/// ya hayan actuado sobre la respuesta.
///
/// El [AppError] resultante se coloca en [DioException.error] para que
/// [ErrorHandler.handle] lo detecte y lo devuelva directamente.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Solo enriquecemos si no es ya un AppError envuelto
    if (err.error is AppError) {
      handler.next(err);
      return;
    }

    final appError = _toAppError(err);
    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: appError,
        message: appError.message,
        stackTrace: err.stackTrace,
      ),
    );
  }

  AppError _toAppError(DioException err) {
    switch (err.type) {
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
        return _fromResponse(err.response);

      default:
        final msg = err.message?.isNotEmpty == true
            ? err.message!
            : 'Error de red desconocido.';
        return AppError(message: msg, code: 'NET_UNKNOWN');
    }
  }

  AppError _fromResponse(Response? response) {
    if (response == null) return AppError.unknown();

    final status = response.statusCode ?? 500;
    if (status == 401) return AppError.unauthorized();
    if (status == 403) return AppError.forbidden();

    final data = response.data;
    if (data is Map<String, dynamic>) {
      // Backend puede devolver ProblemDetail (RFC 9457) o nuestro ErrorResponse
      final msg = _extractMessage(data, status);
      return AppError(
        message: msg,
        statusCode: status,
        code: data['code']?.toString() ??
            data['errorCode']?.toString() ??
            'HTTP_$status',
        traceId: (data['traceId'] ??
                data['trace_id'] ??
                data['requestId'])
            ?.toString(),
      );
    }

    if (data is String && data.isNotEmpty) {
      return AppError(
        message: 'HTTP $status: ${data.length > 200 ? data.substring(0, 200) : data}',
        statusCode: status,
        code: 'HTTP_$status',
      );
    }

    return AppError(
      message: _genericMessage(status),
      statusCode: status,
      code: 'HTTP_$status',
    );
  }

  String _extractMessage(Map<String, dynamic> data, int status) {
    // Intenta en orden: message, error, title (ProblemDetail), detail (ProblemDetail)
    for (final key in ['message', 'error', 'title', 'detail']) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return _genericMessage(status);
  }

  String _genericMessage(int status) {
    if (status >= 500) return 'Error interno del servidor (HTTP $status).';
    if (status == 404) return 'Recurso no encontrado (HTTP 404).';
    if (status == 422) return 'Error de validación (HTTP 422).';
    if (status >= 400) return 'Solicitud inválida (HTTP $status).';
    return 'Error inesperado (HTTP $status).';
  }
}
