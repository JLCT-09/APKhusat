import 'dart:convert';

/// Utilidades para trabajar con tokens JWT.
/// 
/// Permite decodificar el payload del token para extraer información
/// como el uid (user ID) que viene en el campo 'sub' o 'uid'.
class JwtUtils {
  /// Decodifica el payload de un token JWT.
  /// 
  /// Retorna un Map con los datos del payload, o null si el token es inválido.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      
      // Decodificar el payload (segunda parte)
      final payload = parts[1];
      
      // Agregar padding si es necesario para base64
      String normalizedPayload = payload;
      switch (payload.length % 4) {
        case 1:
          normalizedPayload += '===';
          break;
        case 2:
          normalizedPayload += '==';
          break;
        case 3:
          normalizedPayload += '=';
          break;
      }
      
      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
  
  /// Extrae el UID del token JWT.
  /// 
  /// Busca en los campos 'uid' o 'sub' del payload.
  /// Retorna null si no se encuentra.
  static String? extractUid(String token) {
    final payload = decodePayload(token);
    if (payload == null) {
      return null;
    }
    
    // Buscar en 'uid' o 'sub' (estándar JWT)
    return payload['uid']?.toString() ?? 
           payload['sub']?.toString() ?? 
           payload['userId']?.toString();
  }
}
