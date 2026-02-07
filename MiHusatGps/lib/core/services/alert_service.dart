import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../domain/models/device_model.dart';
import '../../domain/models/alert_model.dart';
import 'alert_storage_service.dart';
import 'coordinate_service.dart';

/// Servicio de alertas para notificaciones de velocidad y cobertura.
/// 
/// Monitorea:
/// - Exceso de velocidad (>90 km/h)
/// - Pérdida de cobertura (>10 minutos sin datos)
class AlertService {
  static final AlertService _instance = AlertService._internal();
  factory AlertService() => _instance;
  AlertService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  // Límites de alerta
  static const double speedLimit = 90.0; // km/h
  static const int coverageTimeoutMinutes = 10;
  
  // IDs de notificaciones
  static const int speedAlertId = 100;
  static const int coverageAlertId = 200;
  
  // Mapa para rastrear última notificación por dispositivo (evitar spam)
  final Map<String, DateTime> _lastSpeedAlert = {};
  final Map<String, DateTime> _lastCoverageAlert = {};
  static const Duration alertCooldown = Duration(minutes: 5); // Cooldown de 5 minutos

  /// Inicializa el servicio de alertas
  Future<void> initialize() async {
    // Crear canal de alertas de velocidad
    const androidSpeedChannel = AndroidNotificationChannel(
      'husatgps_speed_alerts',
      'Alertas de Velocidad',
      description: 'Notificaciones de exceso de velocidad',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Crear canal de alertas de cobertura
    const androidCoverageChannel = AndroidNotificationChannel(
      'husatgps_coverage_alerts',
      'Alertas de Cobertura',
      description: 'Notificaciones de pérdida de cobertura',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Registrar canales (Android)
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidSpeedChannel);
    
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidCoverageChannel);
  }

  /// Verifica y dispara alerta de velocidad si es necesario
  Future<void> checkSpeedAlert(DeviceModel device, double? speed) async {
    if (speed == null || speed <= speedLimit) {
      return;
    }

    final deviceId = device.idDispositivo.toString();
    final now = DateTime.now();
    
    // Verificar cooldown
    if (_lastSpeedAlert.containsKey(deviceId)) {
      final lastAlert = _lastSpeedAlert[deviceId]!;
      if (now.difference(lastAlert) < alertCooldown) {
        return; // Aún en cooldown
      }
    }

    final placa = device.placa ?? 'Sin Placa';
    final speedKmh = speed * 3.6; // Convertir m/s a km/h
    final speedKmhStr = speedKmh.toStringAsFixed(1);

    // Obtener coordenadas válidas para el payload
    final coords = await CoordinateService.getValidCoordinates(
      deviceId,
      device.latitude,
      device.longitude,
    );
    final validLat = coords['latitude'] as double;
    final validLng = coords['longitude'] as double;

    // Guardar alerta en el historial
    final alert = AlertModel(
      id: 'speed_${device.idDispositivo}_${now.millisecondsSinceEpoch}',
      type: 'speed',
      deviceId: deviceId,
      placa: placa,
      message: 'El vehículo $placa va a $speedKmhStr km/h',
      timestamp: now,
      latitude: validLat != 0.0 ? validLat : null,
      longitude: validLng != 0.0 ? validLng : null,
      speed: speedKmh,
      isRead: false,
    );
    await AlertStorageService().saveAlert(alert);

    const androidDetails = AndroidNotificationDetails(
      'husatgps_speed_alerts',
      'Alertas de Velocidad',
      channelDescription: 'Notificaciones de exceso de velocidad',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Usar deviceId directamente como ID de notificación para evitar colisiones
    // Esto permite que cada dispositivo tenga su propia notificación
    final notificationId = device.idDispositivo; // ID único por dispositivo
    
    // Payload simplificado: solo deviceId como String
    final payload = device.idDispositivo.toString();
    
    await _notifications.show(
      notificationId,
      '⚠️ Exceso de Velocidad',
      'El vehículo $placa va a $speedKmhStr km/h',
      notificationDetails,
      payload: payload,
    );

    _lastSpeedAlert[deviceId] = now;
  }

  /// Verifica y dispara alerta de cobertura si es necesario
  Future<void> checkCoverageAlert(DeviceModel device, DateTime? lastUpdate) async {
    if (lastUpdate == null) {
      return;
    }

    final now = DateTime.now();
    final minutesSinceUpdate = now.difference(lastUpdate).inMinutes;

    if (minutesSinceUpdate <= coverageTimeoutMinutes) {
      return; // Aún dentro del tiempo permitido
    }

    final deviceId = device.idDispositivo.toString();
    
    // Verificar cooldown
    if (_lastCoverageAlert.containsKey(deviceId)) {
      final lastAlert = _lastCoverageAlert[deviceId]!;
      if (now.difference(lastAlert) < alertCooldown) {
        return; // Aún en cooldown
      }
    }

    final placa = device.placa ?? 'Sin Placa';

    // Obtener coordenadas válidas para el payload
    final coords = await CoordinateService.getValidCoordinates(
      deviceId,
      device.latitude,
      device.longitude,
    );
    final validLat = coords['latitude'] as double;
    final validLng = coords['longitude'] as double;

    // Guardar alerta en el historial
    final alert = AlertModel(
      id: 'coverage_${device.idDispositivo}_${now.millisecondsSinceEpoch}',
      type: 'coverage',
      deviceId: deviceId,
      placa: placa,
      message: 'El vehículo $placa ha perdido conexión',
      timestamp: now,
      latitude: validLat != 0.0 ? validLat : null,
      longitude: validLng != 0.0 ? validLng : null,
      isRead: false,
    );
    await AlertStorageService().saveAlert(alert);

    const androidDetails = AndroidNotificationDetails(
      'husatgps_coverage_alerts',
      'Alertas de Cobertura',
      channelDescription: 'Notificaciones de pérdida de cobertura',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Usar deviceId directamente como ID de notificación para evitar colisiones
    // Esto permite que cada dispositivo tenga su propia notificación
    // Usamos un offset negativo para diferenciar de las alertas de velocidad
    final notificationId = -device.idDispositivo; // ID único por dispositivo (negativo para cobertura)
    
    // Payload simplificado: solo deviceId como String
    final payload = device.idDispositivo.toString();
    
    await _notifications.show(
      notificationId,
      '📡 Sin Cobertura',
      'El vehículo $placa ha perdido conexión',
      notificationDetails,
      payload: payload,
    );

    _lastCoverageAlert[deviceId] = now;
  }

  /// Limpia el historial de alertas (útil para testing)
  void clearAlertHistory() {
    _lastSpeedAlert.clear();
    _lastCoverageAlert.clear();
  }
}
