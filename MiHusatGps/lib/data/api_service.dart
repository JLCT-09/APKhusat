import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/utils/storage_service.dart';
import '../core/exceptions/http_exceptions.dart';

/// Servicio base para realizar peticiones HTTP al backend.
/// 
/// Maneja:
/// - Headers con token JWT
/// - Manejo de errores de conexión
/// - Conversión de respuestas JSON
class ApiService {
  /// Realiza una petición GET al endpoint especificado
  static Future<Map<String, dynamic>?> get(String endpoint) async {
    try {
      debugPrint('📡 HusatGps: Conectado a ${ApiConfig.baseUrl.replaceAll('http://', '').replaceAll(':8080', '')}');
      final token = await StorageService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      debugPrint('🌐 GET: ${url.toString()}');
      debugPrint('📋 Endpoint completo: ${ApiConfig.baseUrl}$endpoint');
      debugPrint('📋 Token presente: ${token != null ? 'Sí' : 'No'}');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('❌ Timeout: El servidor ${ApiConfig.baseUrl} no respondió en 10 segundos');
          throw TimeoutException('El servidor no respondió a tiempo. Verifique su conexión.');
        },
      );

      debugPrint('✅ GET Response: ${response.statusCode} - ${url.toString()}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // Para 404, retornar null en lugar de lanzar excepción
        debugPrint('⚠️ GET 404: Recurso no encontrado en ${url.toString()}');
        return null;
      } else if (response.statusCode == 401) {
        // Token expirado - limpiar y lanzar excepción
        await StorageService.clearToken();
        debugPrint('🔐 GET 401: Token expirado - Sesión cerrada');
        throw UnauthorizedException('Su sesión ha expirado. Por favor, inicie sesión nuevamente.');
      } else if (response.statusCode >= 500) {
        // Error del servidor (500-599)
        debugPrint('🔴 GET ${response.statusCode}: Error del servidor en ${url.toString()}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('📋 RESPONSE BODY COMPLETO (Error 500):');
        debugPrint('${response.body}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('📋 HEADERS ENVIADOS:');
        debugPrint('Content-Type: application/json');
        debugPrint('Authorization: ${token != null ? 'Bearer [TOKEN_PRESENTE]' : 'NO TOKEN'}');
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // Intentar parsear el mensaje de error del servidor si es JSON
        String errorMessage = 'El servidor está en mantenimiento. Por favor, intente más tarde.';
        try {
          final errorJson = json.decode(response.body) as Map<String, dynamic>?;
          if (errorJson != null) {
            final serverMessage = errorJson['message'] ?? 
                                 errorJson['error'] ?? 
                                 errorJson['detail'] ??
                                 errorJson['mensaje'];
            if (serverMessage != null) {
              errorMessage = serverMessage.toString();
              debugPrint('📋 Mensaje de error del servidor: $errorMessage');
            }
          }
        } catch (e) {
          // Si no es JSON, usar el body completo como mensaje
          if (response.body.isNotEmpty && response.body.length < 200) {
            errorMessage = response.body;
          }
        }
        
        throw ServerException(errorMessage);
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode} en GET ${url.toString()}');
        debugPrint('Response body: ${response.body}');
        throw HttpException('Error de comunicación con Husat (Código: ${response.statusCode})', response.statusCode);
      }
    } catch (e) {
      debugPrint('❌ Error en GET ${ApiConfig.baseUrl}$endpoint: $e');
      
      // Manejar errores de red específicos
      if (e is TimeoutException) {
        rethrow; // Ya es una excepción personalizada
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup') ||
                 e.toString().contains('Network is unreachable') ||
                 e.toString().contains('Connection refused')) {
        debugPrint('🔴 ERROR DE CONEXIÓN: No se pudo conectar al servidor ${ApiConfig.baseUrl}');
        debugPrint('   Verifica que el servidor esté accesible y la IP sea correcta');
        throw NetworkException('No se pudo conectar al servidor. Verifique su conexión a internet.');
      }
      rethrow;
    }
  }

  /// Realiza una petición POST al endpoint especificado
  static Future<Map<String, dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      debugPrint('📡 HusatGps: Conectado a ${ApiConfig.baseUrl.replaceAll('http://', '').replaceAll(':8080', '')}');
      final token = await StorageService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      debugPrint('🌐 POST: ${url.toString()}');
      
      // Construir headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      debugPrint('📋 Headers enviados: Content-Type: application/json, Authorization: ${token != null ? 'Bearer [TOKEN_PRESENTE]' : 'NO TOKEN'}');
      debugPrint('📋 Body enviado: ${json.encode(body)}');
      
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('❌ Timeout: El servidor ${ApiConfig.baseUrl} no respondió en 10 segundos');
          throw TimeoutException('El servidor no respondió a tiempo. Verifique su conexión.');
        },
      );

      debugPrint('✅ POST Response: ${response.statusCode} - ${url.toString()}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        // Token expirado - limpiar y lanzar excepción
        await StorageService.clearToken();
        debugPrint('🔐 POST 401: Token expirado - Sesión cerrada');
        throw UnauthorizedException('Su sesión ha expirado. Por favor, inicie sesión nuevamente.');
      } else if (response.statusCode >= 500) {
        // Error del servidor (500-599)
        debugPrint('🔴 POST ${response.statusCode}: Error del servidor en ${url.toString()}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('📋 RESPONSE BODY COMPLETO (Error 500):');
        debugPrint('${response.body}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('📋 HEADERS ENVIADOS:');
        debugPrint('Content-Type: application/json');
        debugPrint('Authorization: ${token != null ? 'Bearer [TOKEN_PRESENTE]' : 'NO TOKEN'}');
        debugPrint('📋 BODY ENVIADO:');
        debugPrint('${json.encode(body)}');
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // Intentar parsear el mensaje de error del servidor si es JSON
        String errorMessage = 'El servidor está en mantenimiento. Por favor, intente más tarde.';
        try {
          final errorJson = json.decode(response.body) as Map<String, dynamic>?;
          if (errorJson != null) {
            final serverMessage = errorJson['message'] ?? 
                                 errorJson['error'] ?? 
                                 errorJson['detail'] ??
                                 errorJson['mensaje'];
            if (serverMessage != null) {
              errorMessage = serverMessage.toString();
              debugPrint('📋 Mensaje de error del servidor: $errorMessage');
            }
          }
        } catch (e) {
          // Si no es JSON, usar el body completo como mensaje
          if (response.body.isNotEmpty && response.body.length < 200) {
            errorMessage = response.body;
          }
        }
        
        throw ServerException(errorMessage);
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode} en POST ${url.toString()}');
        debugPrint('Response body: ${response.body}');
        throw HttpException('Error de comunicación con Husat (Código: ${response.statusCode})', response.statusCode);
      }
    } catch (e) {
      debugPrint('❌ Error en POST ${ApiConfig.baseUrl}$endpoint: $e');
      
      // Manejar errores de red específicos
      if (e is TimeoutException) {
        rethrow; // Ya es una excepción personalizada
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup') ||
                 e.toString().contains('Network is unreachable') ||
                 e.toString().contains('Connection refused')) {
        debugPrint('🔴 ERROR DE CONEXIÓN: No se pudo conectar al servidor ${ApiConfig.baseUrl}');
        debugPrint('   Verifica que el servidor esté accesible y la IP sea correcta');
        throw NetworkException('No se pudo conectar al servidor. Verifique su conexión a internet.');
      }
      rethrow;
    }
  }

  /// Realiza una petición GET que retorna una lista
  static Future<List<dynamic>?> getList(String endpoint) async {
    try {
      debugPrint('📡 HusatGps: Conectado a ${ApiConfig.baseUrl.replaceAll('http://', '').replaceAll(':8080', '')}');
      final token = await StorageService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      debugPrint('🌐 GET LIST: ${url.toString()}');
      debugPrint('📋 Endpoint completo: ${ApiConfig.baseUrl}$endpoint');
      debugPrint('📋 Token presente: ${token != null ? 'Sí' : 'No'}');
      debugPrint('📋 Query parameters: ${url.queryParameters}');
      
      // Construir headers
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      
      debugPrint('📋 Headers enviados: Content-Type: application/json, Authorization: ${token != null ? 'Bearer [TOKEN_PRESENTE]' : 'NO TOKEN'}');
      
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('❌ Timeout: El servidor ${ApiConfig.baseUrl} no respondió en 10 segundos');
          throw TimeoutException('El servidor no respondió a tiempo. Verifique su conexión.');
        },
      );

      debugPrint('✅ GET LIST Response: ${response.statusCode} - ${url.toString()}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else if (response.statusCode == 404) {
        // Para 404, retornar lista vacía en lugar de lanzar excepción
        debugPrint('⚠️ GET LIST 404: Recurso no encontrado en ${url.toString()}');
        return [];
      } else if (response.statusCode == 401) {
        // Token expirado - limpiar y lanzar excepción
        await StorageService.clearToken();
        debugPrint('🔐 GET LIST 401: Token expirado - Sesión cerrada');
        throw UnauthorizedException('Su sesión ha expirado. Por favor, inicie sesión nuevamente.');
      } else if (response.statusCode >= 500) {
        // Error del servidor (500-599)
        debugPrint('🔴 GET LIST ${response.statusCode}: Error del servidor en ${url.toString()}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('📋 RESPONSE BODY COMPLETO (Error 500):');
        debugPrint('${response.body}');
        debugPrint('═══════════════════════════════════════════════════════════');
        debugPrint('📋 HEADERS ENVIADOS:');
        debugPrint('Content-Type: application/json');
        debugPrint('Authorization: ${token != null ? 'Bearer [TOKEN_PRESENTE]' : 'NO TOKEN'}');
        debugPrint('═══════════════════════════════════════════════════════════');
        
        // Intentar parsear el mensaje de error del servidor si es JSON
        String errorMessage = 'El servidor está en mantenimiento. Por favor, intente más tarde.';
        try {
          final errorJson = json.decode(response.body) as Map<String, dynamic>?;
          if (errorJson != null) {
            final serverMessage = errorJson['message'] ?? 
                                 errorJson['error'] ?? 
                                 errorJson['detail'] ??
                                 errorJson['mensaje'];
            if (serverMessage != null) {
              errorMessage = serverMessage.toString();
              debugPrint('📋 Mensaje de error del servidor: $errorMessage');
            }
          }
        } catch (e) {
          // Si no es JSON, usar el body completo como mensaje
          if (response.body.isNotEmpty && response.body.length < 200) {
            errorMessage = response.body;
          }
        }
        
        throw ServerException(errorMessage);
      } else {
        debugPrint('❌ Error HTTP ${response.statusCode} en GET LIST ${url.toString()}');
        debugPrint('Response body: ${response.body}');
        throw HttpException('Error de comunicación con Husat (Código: ${response.statusCode})', response.statusCode);
      }
    } catch (e) {
      debugPrint('❌ Error en GET LIST ${ApiConfig.baseUrl}$endpoint: $e');
      
      // Manejar errores de red específicos
      if (e is TimeoutException) {
        rethrow; // Ya es una excepción personalizada
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup') ||
                 e.toString().contains('Network is unreachable') ||
                 e.toString().contains('Connection refused')) {
        debugPrint('🔴 ERROR DE CONEXIÓN: No se pudo conectar al servidor ${ApiConfig.baseUrl}');
        debugPrint('   Verifica que el servidor esté accesible y la IP sea correcta');
        throw NetworkException('No se pudo conectar al servidor. Verifique su conexión a internet.');
      }
      rethrow;
    }
  }
}
