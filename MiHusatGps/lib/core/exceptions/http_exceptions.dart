/// Excepciones personalizadas para manejo de errores HTTP

/// Excepción base para errores HTTP
class HttpException implements Exception {
  final String message;
  final int? statusCode;
  
  HttpException(this.message, [this.statusCode]);
  
  @override
  String toString() => message;
}

/// Excepción para errores del servidor (500-599)
class ServerException extends HttpException {
  ServerException([String? message]) 
      : super(message ?? 'El servidor está experimentando problemas. Por favor, intente más tarde.', 500);
}

/// Excepción para errores de autorización (401)
class UnauthorizedException extends HttpException {
  UnauthorizedException([String? message])
      : super(message ?? 'Su sesión ha expirado. Por favor, inicie sesión nuevamente.', 401);
}

/// Excepción para recursos no encontrados (404)
class NotFoundException extends HttpException {
  NotFoundException([String? message])
      : super(message ?? 'Recurso no encontrado.', 404);
}

/// Excepción para timeouts
class TimeoutException extends HttpException {
  TimeoutException([String? message])
      : super(message ?? 'El servidor no respondió a tiempo. Verifique su conexión.', 408);
}

/// Excepción para errores de red (conexión, DNS, etc.)
class NetworkException extends HttpException {
  NetworkException([String? message])
      : super(message ?? 'Error de conexión. Verifique su conexión a internet y que el servidor esté accesible.', null);
}
