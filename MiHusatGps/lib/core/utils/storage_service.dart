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
  static const String _keyUserRolId = 'user_rol_id'; // ID numérico del rol (1=Admin, 2=Distribuidor, etc.)
  static const String _keyNombreCompleto = 'nombre_completo';
  static const String _keyPassword = 'user_password'; // Para validación de comandos
  
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
  
  /// Elimina el token JWT del almacenamiento local
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
  }
  
  /// Elimina el ID del usuario del almacenamiento local
  static Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }
  
  /// Elimina el rol del usuario del almacenamiento local
  static Future<void> clearUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserRole);
  }
  
  /// Elimina el nombre completo del usuario del almacenamiento local
  static Future<void> clearNombreCompleto() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyNombreCompleto);
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
  
  /// Guarda el rolId del usuario (ID numérico del rol)
  static Future<void> saveUserRolId(int rolId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserRolId, rolId);
  }
  
  /// Obtiene el rolId del usuario guardado
  static Future<int?> getUserRolId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyUserRolId);
  }
  
  /// Verifica si el usuario es admin (rolId == 1)
  static Future<bool> isAdminByRolId() async {
    final rolId = await getUserRolId();
    return rolId == 1;
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
  
  /// Guarda la contraseña del usuario (para validación de comandos)
  static Future<void> savePassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPassword, password);
  }

  /// Obtiene la contraseña guardada
  static Future<String?> getPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPassword);
  }

  /// Verifica si la contraseña proporcionada coincide con la guardada
  static Future<bool> verifyPassword(String password) async {
    final savedPassword = await getPassword();
    return savedPassword != null && savedPassword == password;
  }

  /// Elimina todos los datos de sesión
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyUserRolId);
    await prefs.remove(_keyNombreCompleto);
    await prefs.remove(_keyPassword);
  }
}
