import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para guardar y recuperar datos del almacenamiento local.
/// 
/// Usa SharedPreferences para persistir:
/// - Token JWT del usuario autenticado
/// - ID del usuario
/// - Otros datos de sesión
class StorageService {
  static const String _keyToken = 'jwt_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserRole = 'user_role';
  static const String _keyNombreCompleto = 'nombre_completo';
  
  /// Guarda el token JWT en el almacenamiento local
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }
  
  /// Obtiene el token JWT guardado
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }
  
  /// Guarda el ID del usuario
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }
  
  /// Obtiene el ID del usuario guardado
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }
  
  /// Guarda el rol del usuario
  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role);
  }
  
  /// Obtiene el rol del usuario guardado
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole);
  }
  
  /// Guarda el nombre completo del usuario
  static Future<void> saveNombreCompleto(String nombreCompleto) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNombreCompleto, nombreCompleto);
  }
  
  /// Obtiene el nombre completo del usuario guardado
  static Future<String?> getNombreCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNombreCompleto);
  }
  
  /// Elimina todos los datos de sesión
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyNombreCompleto);
  }
}
