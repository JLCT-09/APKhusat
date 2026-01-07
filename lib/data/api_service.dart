import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../core/utils/storage_service.dart';

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
      final token = await StorageService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: El servidor no respondió');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error de comunicación con Husat (Código: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error en GET $endpoint: $e');
      rethrow;
    }
  }

  /// Realiza una petición POST al endpoint especificado
  static Future<Map<String, dynamic>?> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await StorageService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: El servidor no respondió');
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Error de comunicación con Husat (Código: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error en POST $endpoint: $e');
      rethrow;
    }
  }

  /// Realiza una petición GET que retorna una lista
  static Future<List<dynamic>?> getList(String endpoint) async {
    try {
      final token = await StorageService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: El servidor no respondió');
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as List<dynamic>;
      } else {
        throw Exception('Error de comunicación con Husat (Código: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error en GET LIST $endpoint: $e');
      rethrow;
    }
  }
}
