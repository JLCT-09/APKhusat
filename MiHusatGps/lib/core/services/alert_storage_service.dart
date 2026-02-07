import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/alert_model.dart';

/// Servicio para persistir alertas localmente usando SharedPreferences.
class AlertStorageService {
  static final AlertStorageService _instance = AlertStorageService._internal();
  factory AlertStorageService() => _instance;
  AlertStorageService._internal();

  static const String _alertsKey = 'husatgps_alerts';
  static const int _maxAlerts = 1000; // Límite de alertas guardadas

  /// Guarda una alerta en el almacenamiento local
  Future<void> saveAlert(AlertModel alert) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alerts = await getAllAlerts();
      
      // Añadir la nueva alerta al inicio
      alerts.insert(0, alert);
      
      // Limitar el número de alertas guardadas
      if (alerts.length > _maxAlerts) {
        alerts.removeRange(_maxAlerts, alerts.length);
      }
      
      // Guardar en SharedPreferences
      final alertsJson = alerts.map((a) => a.toJson()).toList();
      await prefs.setString(_alertsKey, jsonEncode(alertsJson));
    } catch (e) {
      // Error silencioso - no queremos que falle la app por guardar alertas
    }
  }

  /// Obtiene todas las alertas guardadas
  Future<List<AlertModel>> getAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = prefs.getString(_alertsKey);
      
      if (alertsJson == null || alertsJson.isEmpty) {
        return [];
      }
      
      final List<dynamic> decoded = jsonDecode(alertsJson);
      return decoded.map((json) => AlertModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene las alertas no leídas
  Future<List<AlertModel>> getUnreadAlerts() async {
    final alerts = await getAllAlerts();
    return alerts.where((alert) => !alert.isRead).toList();
  }

  /// Marca una alerta como leída
  Future<void> markAsRead(String alertId) async {
    try {
      final alerts = await getAllAlerts();
      final index = alerts.indexWhere((alert) => alert.id == alertId);
      
      if (index != -1) {
        alerts[index] = alerts[index].copyWith(isRead: true);
        
        final prefs = await SharedPreferences.getInstance();
        final alertsJson = alerts.map((a) => a.toJson()).toList();
        await prefs.setString(_alertsKey, jsonEncode(alertsJson));
      }
    } catch (e) {
      // Error silencioso
    }
  }

  /// Marca todas las alertas como leídas
  Future<void> markAllAsRead() async {
    try {
      final alerts = await getAllAlerts();
      final updatedAlerts = alerts.map((alert) => alert.copyWith(isRead: true)).toList();
      
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = updatedAlerts.map((a) => a.toJson()).toList();
      await prefs.setString(_alertsKey, jsonEncode(alertsJson));
    } catch (e) {
      // Error silencioso
    }
  }

  /// Elimina una alerta
  Future<void> deleteAlert(String alertId) async {
    try {
      final alerts = await getAllAlerts();
      alerts.removeWhere((alert) => alert.id == alertId);
      
      final prefs = await SharedPreferences.getInstance();
      final alertsJson = alerts.map((a) => a.toJson()).toList();
      await prefs.setString(_alertsKey, jsonEncode(alertsJson));
    } catch (e) {
      // Error silencioso
    }
  }

  /// Elimina todas las alertas
  Future<void> clearAllAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_alertsKey);
    } catch (e) {
      // Error silencioso
    }
  }

  /// Obtiene el número de alertas no leídas
  Future<int> getUnreadCount() async {
    final unread = await getUnreadAlerts();
    return unread.length;
  }
}
