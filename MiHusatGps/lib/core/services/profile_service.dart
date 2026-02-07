import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestionar el perfil del usuario localmente.
class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  static const String _nameKey = 'user_profile_name';
  static const String _phoneKey = 'user_profile_phone';
  static const String _photoPathKey = 'user_profile_photo_path';
  static const String _notificationsSoundKey = 'user_notifications_sound';

  /// Guarda el nombre del usuario
  Future<void> saveName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
  }

  /// Obtiene el nombre guardado del usuario
  Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey);
  }

  /// Guarda el número de celular del usuario
  Future<void> savePhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  /// Obtiene el número de celular guardado
  Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  /// Guarda la ruta de la foto de perfil
  Future<void> savePhotoPath(String? photoPath) async {
    final prefs = await SharedPreferences.getInstance();
    if (photoPath != null) {
      await prefs.setString(_photoPathKey, photoPath);
    } else {
      await prefs.remove(_photoPathKey);
    }
  }

  /// Obtiene la ruta de la foto de perfil
  Future<String?> getPhotoPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_photoPathKey);
  }

  /// Guarda la preferencia de sonido de notificaciones
  Future<void> saveNotificationsSound(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsSoundKey, enabled);
  }

  /// Obtiene la preferencia de sonido de notificaciones
  Future<bool> getNotificationsSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsSoundKey) ?? true; // Por defecto activado
  }

  /// Limpia todos los datos del perfil
  Future<void> clearProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_photoPathKey);
    await prefs.remove(_notificationsSoundKey);
  }
}
