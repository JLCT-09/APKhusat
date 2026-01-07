import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/models/user.dart';
import '../core/config/api_config.dart';
import '../core/utils/storage_service.dart';
import '../core/utils/jwt_utils.dart';

/// Servicio de autenticación que se conecta al backend de producción.
/// 
/// Realiza login con credenciales reales según especificaciones de Swagger.
class AuthService {
  /// Realiza login con las credenciales proporcionadas.
  /// 
  /// Hace POST a /api/AutenticacionControlador/login
  /// Body: { "nombreUsuario": "Jherson", "clave": "123456" }
  /// 
  /// Mapea la respuesta:
  /// - token → Guarda en SharedPreferences
  /// - nombreCompleto → Guarda para mostrar en perfil
  /// - rol → Guarda (valor será 'Distribuidor')
  /// - uid → Extrae del token JWT (campo 'uid' o 'sub')
  /// 
  /// Retorna un objeto User si el login es exitoso, null en caso contrario.
  Future<User?> login(String nombreUsuario, String clave) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}');
      
      // Body según especificaciones de Swagger
      final body = {
        'nombreUsuario': nombreUsuario,
        'clave': clave,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout: El servidor no respondió');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        final token = data['token'] as String? ?? '';
        final nombreCompleto = data['nombreCompleto'] as String? ?? nombreUsuario;
        final rol = data['rol'] as String? ?? 'Distribuidor';
        
        String? userId;
        if (token.isNotEmpty) {
          userId = JwtUtils.extractUid(token);
        }
        
        userId ??= data['usuarioId']?.toString() ?? data['id']?.toString() ?? '6';
        
        UserRole userRole = UserRole.client;
        if (rol.toLowerCase().contains('admin') || 
            rol.toLowerCase().contains('administrador') ||
            rol.toLowerCase().contains('distribuidor')) {
          userRole = UserRole.admin;
        }
        
        if (token.isNotEmpty) {
          await StorageService.saveToken(token);
          await StorageService.saveUserId(userId);
          await StorageService.saveUserRole(rol);
          await StorageService.saveNombreCompleto(nombreCompleto);
        }
        
        return User(
          id: userId,
          nombre: nombreCompleto,
          email: nombreUsuario, // Usar nombreUsuario como email si no viene
          token: token,
          role: userRole,
          vehicleId: data['vehiculoId']?.toString(),
        );
      } else {
        // Error en la respuesta del servidor
        debugPrint('❌ Error en login: ${response.statusCode} - ${response.body}');
        throw Exception('Error de comunicación con Husat (Código: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error en login: $e');
      rethrow;
    }
  }

  /// Cierra sesión y elimina los datos guardados.
  Future<void> logout() async {
    await StorageService.clearAll();
  }
}
