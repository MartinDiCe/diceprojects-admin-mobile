class AppError implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final String? details;
  final String? traceId;

  const AppError({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
    this.traceId,
  });

  @override
  String toString() => 'AppError($statusCode): $message';

  factory AppError.fromJson(Map<String, dynamic> json) {
    return AppError(
      message: (json['message'] ?? json['error'] ?? 'Error desconocido')
          .toString(),
      statusCode: (json['status'] as num?)?.toInt() ??
          int.tryParse((json['status'] ?? '').toString()),
      code: json['code']?.toString(),
      traceId: (json['traceId'] ?? json['trace_id'] ?? json['requestId'])
          ?.toString(),
    );
  }

  factory AppError.network() => const AppError(
        message: 'Error de red. Verificá tu conexión a internet.',
        code: 'NETWORK_ERROR',
      );

  factory AppError.unauthorized() => const AppError(
        message: 'Sesión expirada. Iniciá sesión nuevamente.',
        code: 'UNAUTHORIZED',
        statusCode: 401,
      );

  factory AppError.forbidden() => const AppError(
        message: 'No tenés permisos para realizar esta acción.',
        code: 'FORBIDDEN',
        statusCode: 403,
      );

  factory AppError.unknown() => const AppError(
        message: 'Error inesperado. Por favor, intentá de nuevo.',
        code: 'UNKNOWN',
      );
}
